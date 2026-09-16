import { createClient } from '@supabase/supabase-js';

type NetlifyEvent = {
  httpMethod?: string;
  headers?: Record<string, string | undefined>;
  body?: string | null;
};

export const handler = async (event: NetlifyEvent) => {
  if (event.httpMethod !== 'POST') {
    return {
      statusCode: 405,
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        error: 'Method not allowed',
      }),
    };
  }

  try {
    const supabaseUrl = process.env.SUPABASE_URL;
    const serviceRoleKey =
      process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!supabaseUrl || !serviceRoleKey) {
      return {
        statusCode: 500,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          error:
            'SUPABASE_URL atau SUPABASE_SERVICE_ROLE_KEY belum dikonfigurasi di Netlify.',
        }),
      };
    }

    const authorization =
      event.headers?.authorization ||
      event.headers?.Authorization ||
      '';

    const token = authorization.replace(/^Bearer\s+/i, '').trim();

    if (!token) {
      return {
        statusCode: 401,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          error: 'Sesi login tidak ditemukan.',
        }),
      };
    }

    const supabase = createClient(
      supabaseUrl,
      serviceRoleKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );

    /*
     * ================================
     * 1. VALIDASI USER HR
     * ================================
     */

    const {
      data: authData,
      error: authError,
    } = await supabase.auth.getUser(token);

    if (authError || !authData.user) {
      return {
        statusCode: 401,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          error: 'Sesi login tidak valid.',
        }),
      };
    }

    const currentEmail =
      authData.user.email?.trim() || '';

    if (!currentEmail) {
      return {
        statusCode: 403,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          error: 'Email akun HR tidak ditemukan.',
        }),
      };
    }

    /*
     * ================================
     * 2. CEK ROLE HR
     * ================================
     */

    const {
      data: hrUser,
      error: hrError,
    } = await supabase
      .from('hris_users')
      .select('role,status,email')
      .ilike('email', currentEmail)
      .maybeSingle();

    if (hrError) {
      return {
        statusCode: 500,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          error: hrError.message,
        }),
      };
    }

    if (!hrUser) {
      return {
        statusCode: 403,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          error:
            'Akun Anda belum terdaftar sebagai pengguna HRIS.',
        }),
      };
    }

    if (hrUser.status !== 'Aktif') {
      return {
        statusCode: 403,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          error:
            'Akun HR Anda belum aktif.',
        }),
      };
    }

    const allowedRoles = [
      'Super Admin',
      'Admin',
      'HRD',
    ];

    if (!allowedRoles.includes(hrUser.role)) {
      return {
        statusCode: 403,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          error:
            'Role Anda tidak memiliki izin untuk mengonfirmasi email karyawan.',
        }),
      };
    }

    /*
     * ================================
     * 3. BACA REQUEST
     * ================================
     */

    let body: {
      employee_id?: string;
    } = {};

    try {
      body = JSON.parse(event.body || '{}');
    } catch {
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          error: 'Format request tidak valid.',
        }),
      };
    }

    const employeeId =
      body.employee_id?.trim();

    if (!employeeId) {
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          error:
            'ID karyawan tidak ditemukan.',
        }),
      };
    }

    /*
     * ================================
     * 4. CARI KARYAWAN
     * ================================
     */

    const {
      data: employee,
      error: employeeError,
    } = await supabase
      .from('karyawan')
      .select(
        'id,id_karyawan,nama,email,auth_user_id,email_terverifikasi'
      )
      .eq('id', employeeId)
      .maybeSingle();

    if (employeeError) {
      return {
        statusCode: 500,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          error: employeeError.message,
        }),
      };
    }

    if (!employee) {
      return {
        statusCode: 404,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          error:
            'Data karyawan tidak ditemukan.',
        }),
      };
    }

    if (!employee.email) {
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          error:
            'Karyawan belum memiliki email.',
        }),
      };
    }

    if (!employee.auth_user_id) {
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          error:
            'Akun login karyawan belum terhubung.',
        }),
      };
    }

    /*
     * ================================
     * 5. KONFIRMASI EMAIL SUPABASE AUTH
     * ================================
     */

    const {
      error: confirmError,
    } =
      await supabase.auth.admin.updateUserById(
        employee.auth_user_id,
        {
          email_confirm: true,
        }
      );

    if (confirmError) {
      return {
        statusCode: 500,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          error:
            confirmError.message ||
            'Email gagal dikonfirmasi.',
        }),
      };
    }

    /*
     * ================================
     * 6. SIMPAN STATUS DI KARYAWAN
     * ================================
     */

    const {
      error: updateError,
    } = await supabase
      .from('karyawan')
      .update({
        email_terverifikasi: true,
      })
      .eq('id', employee.id);

    if (updateError) {
      return {
        statusCode: 500,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          error:
            updateError.message,
        }),
      };
    }

    /*
     * ================================
     * 7. RESPONSE
     * ================================
     */

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        success: true,
        message:
          `Email ${employee.email} berhasil dikonfirmasi.`,
        employee_id: employee.id,
        id_karyawan: employee.id_karyawan,
        nama: employee.nama,
      }),
    };
  } catch (error: unknown) {
    const message =
      error instanceof Error
        ? error.message
        : 'Server error.';

    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        error: message,
      }),
    };
  }
};

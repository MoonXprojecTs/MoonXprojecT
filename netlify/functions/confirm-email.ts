import type { Handler } from '@netlify/functions';
import { createClient } from '@supabase/supabase-js';

export const handler: Handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return {
      statusCode: 405,
      body: JSON.stringify({ error: 'Method not allowed' }),
    };
  }

  try {
    const token =
      event.headers.authorization?.replace('Bearer ', '') || '';

    if (!token) {
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    const supabase = createClient(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    );

    // Cek user HR yang sedang login
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return {
        statusCode: 401,
        body: JSON.stringify({
          error: 'Sesi login tidak valid.',
        }),
      };
    }

    // Cek role HR
    const { data: hr, error: hrError } = await supabase
      .from('hris_users')
      .select('role,status')
      .ilike('email', user.email || '')
      .maybeSingle();

    if (
      hrError ||
      !hr ||
      hr.status !== 'Aktif' ||
      !['Super Admin', 'Admin', 'HRD'].includes(hr.role)
    ) {
      return {
        statusCode: 403,
        body: JSON.stringify({
          error: 'Anda tidak memiliki izin.',
        }),
      };
    }

    const body = JSON.parse(event.body || '{}');

    if (!body.employee_id) {
      return {
        statusCode: 400,
        body: JSON.stringify({
          error: 'ID karyawan tidak ditemukan.',
        }),
      };
    }

    // Ambil karyawan
    const { data: employee, error: employeeError } =
      await supabase
        .from('karyawan')
        .select('id,auth_user_id,email')
        .eq('id', body.employee_id)
        .maybeSingle();

    if (employeeError || !employee) {
      return {
        statusCode: 404,
        body: JSON.stringify({
          error: 'Karyawan tidak ditemukan.',
        }),
      };
    }

    if (!employee.auth_user_id) {
      return {
        statusCode: 400,
        body: JSON.stringify({
          error: 'Karyawan belum memiliki akun login.',
        }),
      };
    }

    // Konfirmasi email Supabase Auth
    const { error: confirmError } =
      await supabase.auth.admin.updateUserById(
        employee.auth_user_id,
        {
          email_confirm: true,
        }
      );

    if (confirmError) {
      return {
        statusCode: 500,
        body: JSON.stringify({
          error: confirmError.message,
        }),
      };
    }

    // Tandai di tabel karyawan
    const { error: updateError } = await supabase
      .from('karyawan')
      .update({
        email_terverifikasi: true,
      })
      .eq('id', employee.id);

    if (updateError) {
      return {
        statusCode: 500,
        body: JSON.stringify({
          error: updateError.message,
        }),
      };
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        success: true,
        message: 'Email berhasil dikonfirmasi.',
      }),
    };
  } catch (error: any) {
    return {
      statusCode: 500,
      body: JSON.stringify({
        error: error.message || 'Server error.',
      }),
    };
  }
};

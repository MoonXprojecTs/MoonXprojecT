import { useEffect, useState, type FormEvent } from 'react';
import { supabase } from '../../../lib/supabase/client';
import AdminIcon from '../common/AdminIcon';

type Tab = 'cabang' | 'departemen' | 'jabatan' | 'shift' | 'jadwal';

type Cabang = {
  id: string;
  kode: string;
  nama: string;
  kota: string;
  alamat: string;
  status_aktif: boolean;
};

type Departemen = {
  id: string;
  nama: string;
  kode: string;
  kepala_departemen: string;
  status: string;
};

type Jabatan = {
  id: string;
  nama: string;
  kode: string;
  departemen: string;
  level_jabatan: string;
  status: string;
};

type Shift = {
  id: string;
  nama: string;
  jam_masuk: string | null;
  jam_pulang: string | null;
  istirahat_menit: number;
  toleransi_menit: number;
  status: string;
};

type Karyawan = {
  id: string;
  id_karyawan: string;
  nama: string;
};

type Jadwal = {
  id: string;
  id_karyawan: string;
  tanggal: string;
  shift_id: string | null;
  status: string;
  catatan: string | null;
};



const emptyCabang = {
  kode: '',
  nama: '',
  kota: '',
  alamat: '',
  status_aktif: true,
};

const emptyDepartemen = {
  nama: '',
  kode: '',
  kepala_departemen: '',
  status: 'Aktif',
};

const emptyJabatan = {
  nama: '',
  kode: '',
  departemen: '',
  level_jabatan: '',
  status: 'Aktif',
};

const emptyShift = {
  nama: '',
  jam_masuk: '07:00',
  jam_pulang: '16:00',
  istirahat_menit: 60,
  toleransi_menit: 10,
  status: 'Aktif',
};

const emptyJadwal = {
  id_karyawan: '',
  tanggal: new Date().toISOString().slice(0, 10),
  shift_id: '',
  status: 'Terjadwal',
  catatan: '',
};

export default function MasterData({
  initialTab = 'cabang',
}: {
  initialTab?: Tab;
}) {
  const [tab, setTab] = useState<Tab>(initialTab);

  useEffect(() => {
    setTab(initialTab);
  }, [initialTab]);

  return (
    <div style={styles.wrapper}>
      <div style={styles.header}>
        <div>
          <div style={styles.eyebrow}>MASTER DATA HRIS</div>
          <h1 style={styles.title}>Cabang & Operasional</h1>
          <p style={styles.subtitle}>
            Kelola cabang, departemen, jabatan, shift, dan jadwal karyawan.
          </p>
        </div>
      </div>

      <div style={styles.tabs}>
        <TabButton
          active={tab === 'cabang'}
          icon="building"
          label="Cabang"
          onClick={() => setTab('cabang')}
        />

        <TabButton
          active={tab === 'departemen'}
          icon="folder"
          label="Departemen"
          onClick={() => setTab('departemen')}
        />

        <TabButton
          active={tab === 'jabatan'}
          icon="target"
          label="Jabatan"
          onClick={() => setTab('jabatan')}
        />

        <TabButton
          active={tab === 'shift'}
          icon="shift"
          label="Shift"
          onClick={() => setTab('shift')}
        />

        <TabButton
          active={tab === 'jadwal'}
          icon="calendar"
          label="Jadwal"
          onClick={() => setTab('jadwal')}
        />
      </div>

      {tab === 'cabang' && <CabangModule />}
      {tab === 'departemen' && <DepartemenModule />}
      {tab === 'jabatan' && <JabatanModule />}
      {tab === 'shift' && <ShiftModule />}
      {tab === 'jadwal' && <JadwalModule />}
    </div>
  );
}

/* =========================================================
   TAB BUTTON
========================================================= */

function TabButton({
  active,
  icon,
  label,
  onClick,
}: {
  active: boolean;
  icon: string;
  label: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      style={{
        ...styles.tab,
        ...(active ? styles.tabActive : {}),
      }}
    >
      <span><AdminIcon name={icon} size={16} /></span>
      {label}
    </button>
  );
}

/* =========================================================
   CABANG
========================================================= */

function CabangModule() {
  const [data, setData] = useState<Cabang[]>([]);
  const [loading, setLoading] = useState(true);
  const [modal, setModal] = useState(false);
  const [editing, setEditing] = useState<Cabang | null>(null);
  const [form, setForm] = useState(emptyCabang);
  const [search, setSearch] = useState('');

  const load = async () => {
    setLoading(true);

    const { data, error } = await supabase
      .from('hris_cabang')
      .select('*')
      .order('nama');

    if (error) {
      alert(`Gagal mengambil data cabang:\n${error.message}`);
      setData([]);
    } else {
      setData((data || []) as Cabang[]);
    }

    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const openAdd = () => {
    setEditing(null);
    setForm(emptyCabang);
    setModal(true);
  };

  const openEdit = (item: Cabang) => {
    setEditing(item);

    setForm({
      kode: item.kode || '',
      nama: item.nama || '',
      kota: item.kota || '',
      alamat: item.alamat || '',
      status_aktif: item.status_aktif !== false,
    });

    setModal(true);
  };

  const save = async (e: FormEvent) => {
    e.preventDefault();

    if (!form.nama.trim()) {
      alert('Nama cabang wajib diisi.');
      return;
    }

    const payload = {
      kode: form.kode.trim() || null,
      nama: form.nama.trim(),
      kota: form.kota.trim() || null,
      alamat: form.alamat.trim() || null,
      status_aktif: form.status_aktif,
    };

    let error;

    if (editing) {
      ({ error } = await supabase
        .from('hris_cabang')
        .update(payload)
        .eq('id', editing.id));
    } else {
      ({ error } = await supabase
        .from('hris_cabang')
        .insert(payload));
    }

    if (error) {
      alert(`Gagal menyimpan cabang:\n${error.message}`);
      return;
    }

    setModal(false);
    await load();
  };

  const remove = async (id: string) => {
    if (!confirm('Hapus cabang ini?')) return;

    const { error } = await supabase
      .from('hris_cabang')
      .delete()
      .eq('id', id);

    if (error) {
      alert(`Gagal menghapus:\n${error.message}`);
      return;
    }

    await load();
  };

  const filtered = data.filter((item) =>
    `${item.kode} ${item.nama} ${item.kota}`
      .toLowerCase()
      .includes(search.toLowerCase())
  );

  return (
    <>
      <SectionHeader
        title="Cabang"
        description="Kelola seluruh lokasi/cabang perusahaan."
        button="+ Tambah Cabang"
        onClick={openAdd}
      />

      <div style={styles.toolbar}>
        <input
          style={styles.search}
          placeholder="Cari kode, nama, atau kota..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      <TableCard>
        <table style={styles.table}>
          <thead>
            <tr>
              <th>Kode</th>
              <th>Nama Cabang</th>
              <th>Kota</th>
              <th>Alamat</th>
              <th>Status</th>
              <th style={{ width: 150 }}>Aksi</th>
            </tr>
          </thead>

          <tbody>
            {loading ? (
              <EmptyRow text="Memuat data..." colSpan={6} />
            ) : filtered.length === 0 ? (
              <EmptyRow text="Belum ada data cabang." colSpan={6} />
            ) : (
              filtered.map((item) => (
                <tr key={item.id}>
                  <td>
                    <strong>{item.kode || '-'}</strong>
                  </td>

                  <td>{item.nama}</td>

                  <td>{item.kota || '-'}</td>

                  <td>{item.alamat || '-'}</td>

                  <td>
                    <StatusBadge active={item.status_aktif} />
                  </td>

                  <td>
                    <ActionButtons
                      onEdit={() => openEdit(item)}
                      onDelete={() => remove(item.id)}
                    />
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </TableCard>

      {modal && (
        <Modal
          title={editing ? 'Edit Cabang' : 'Tambah Cabang'}
          onClose={() => setModal(false)}
        >
          <form onSubmit={save}>
            <Input
              label="Kode Cabang"
              value={form.kode}
              onChange={(v) => setForm({ ...form, kode: v })}
              placeholder="Contoh: JKT01"
            />

            <Input
              label="Nama Cabang"
              value={form.nama}
              onChange={(v) => setForm({ ...form, nama: v })}
              placeholder="Contoh: Jakarta"
              required
            />

            <Input
              label="Kota"
              value={form.kota}
              onChange={(v) => setForm({ ...form, kota: v })}
              placeholder="Contoh: Jakarta"
            />

            <Textarea
              label="Alamat"
              value={form.alamat}
              onChange={(v) => setForm({ ...form, alamat: v })}
              placeholder="Alamat lengkap cabang"
            />

            <Checkbox
              label="Cabang aktif"
              checked={form.status_aktif}
              onChange={(v) => setForm({ ...form, status_aktif: v })}
            />

            <FormActions onCancel={() => setModal(false)} />
          </form>
        </Modal>
      )}
    </>
  );
}

/* =========================================================
   DEPARTEMEN
========================================================= */

function DepartemenModule() {
  const [data, setData] = useState<Departemen[]>([]);
  const [loading, setLoading] = useState(true);
  const [modal, setModal] = useState(false);
  const [editing, setEditing] = useState<Departemen | null>(null);
  const [form, setForm] = useState(emptyDepartemen);
  const [search, setSearch] = useState('');

  const load = async () => {
    setLoading(true);

    const { data, error } = await supabase
      .from('hris_departemen')
      .select('*')
      .order('nama');

    if (error) {
      alert(`Gagal mengambil departemen:\n${error.message}`);
      setData([]);
    } else {
      setData((data || []) as Departemen[]);
    }

    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const openAdd = () => {
    setEditing(null);
    setForm(emptyDepartemen);
    setModal(true);
  };

  const openEdit = (item: Departemen) => {
    setEditing(item);

    setForm({
      nama: item.nama || '',
      kode: item.kode || '',
      kepala_departemen: item.kepala_departemen || '',
      status: item.status || 'Aktif',
    });

    setModal(true);
  };

  const save = async (e: FormEvent) => {
    e.preventDefault();

    if (!form.nama.trim()) {
      alert('Nama departemen wajib diisi.');
      return;
    }

    const payload = {
      nama: form.nama.trim(),
      kode: form.kode.trim() || null,
      kepala_departemen: form.kepala_departemen.trim() || null,
      status: form.status,
    };

    let error;

    if (editing) {
      ({ error } = await supabase
        .from('hris_departemen')
        .update(payload)
        .eq('id', editing.id));
    } else {
      ({ error } = await supabase
        .from('hris_departemen')
        .insert(payload));
    }

    if (error) {
      alert(`Gagal menyimpan departemen:\n${error.message}`);
      return;
    }

    setModal(false);
    await load();
  };

  const remove = async (id: string) => {
    if (!confirm('Hapus departemen ini?')) return;

    const { error } = await supabase
      .from('hris_departemen')
      .delete()
      .eq('id', id);

    if (error) {
      alert(`Gagal menghapus:\n${error.message}`);
      return;
    }

    await load();
  };

  const filtered = data.filter((item) =>
    `${item.kode} ${item.nama} ${item.kepala_departemen}`
      .toLowerCase()
      .includes(search.toLowerCase())
  );

  return (
    <>
      <SectionHeader
        title="Departemen"
        description="Kelola struktur departemen perusahaan."
        button="+ Tambah Departemen"
        onClick={openAdd}
      />

      <div style={styles.toolbar}>
        <input
          style={styles.search}
          placeholder="Cari departemen..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      <TableCard>
        <table style={styles.table}>
          <thead>
            <tr>
              <th>Kode</th>
              <th>Departemen</th>
              <th>Kepala Departemen</th>
              <th>Status</th>
              <th>Aksi</th>
            </tr>
          </thead>

          <tbody>
            {loading ? (
              <EmptyRow text="Memuat data..." colSpan={5} />
            ) : filtered.length === 0 ? (
              <EmptyRow text="Belum ada departemen." colSpan={5} />
            ) : (
              filtered.map((item) => (
                <tr key={item.id}>
                  <td>
                    <strong>{item.kode || '-'}</strong>
                  </td>

                  <td>{item.nama}</td>

                  <td>{item.kepala_departemen || '-'}</td>

                  <td>
                    <StatusText value={item.status} />
                  </td>

                  <td>
                    <ActionButtons
                      onEdit={() => openEdit(item)}
                      onDelete={() => remove(item.id)}
                    />
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </TableCard>

      {modal && (
        <Modal
          title={editing ? 'Edit Departemen' : 'Tambah Departemen'}
          onClose={() => setModal(false)}
        >
          <form onSubmit={save}>
            <Input
              label="Kode"
              value={form.kode}
              onChange={(v) => setForm({ ...form, kode: v })}
              placeholder="Contoh: WH"
            />

            <Input
              label="Nama Departemen"
              value={form.nama}
              onChange={(v) => setForm({ ...form, nama: v })}
              placeholder="Contoh: Warehouse"
              required
            />

            <Input
              label="Kepala Departemen"
              value={form.kepala_departemen}
              onChange={(v) =>
                setForm({ ...form, kepala_departemen: v })
              }
              placeholder="Nama kepala departemen"
            />

            <Select
              label="Status"
              value={form.status}
              onChange={(v) => setForm({ ...form, status: v })}
              options={['Aktif', 'Nonaktif']}
            />

            <FormActions onCancel={() => setModal(false)} />
          </form>
        </Modal>
      )}
    </>
  );
}

/* =========================================================
   JABATAN
========================================================= */

function JabatanModule() {
  const [data, setData] = useState<Jabatan[]>([]);
  const [departemen, setDepartemen] = useState<Departemen[]>([]);
  const [loading, setLoading] = useState(true);
  const [modal, setModal] = useState(false);
  const [editing, setEditing] = useState<Jabatan | null>(null);
  const [form, setForm] = useState(emptyJabatan);
  const [search, setSearch] = useState('');

  const load = async () => {
    setLoading(true);

    const [jabatanResult, deptResult] = await Promise.all([
      supabase
        .from('hris_jabatan')
        .select('*')
        .order('nama'),

      supabase
        .from('hris_departemen')
        .select('*')
        .order('nama'),
    ]);

    if (jabatanResult.error) {
      alert(`Gagal mengambil jabatan:\n${jabatanResult.error.message}`);
      setData([]);
    } else {
      setData((jabatanResult.data || []) as Jabatan[]);
    }

    if (!deptResult.error) {
      setDepartemen((deptResult.data || []) as Departemen[]);
    }

    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const openAdd = () => {
    setEditing(null);
    setForm(emptyJabatan);
    setModal(true);
  };

  const openEdit = (item: Jabatan) => {
    setEditing(item);

    setForm({
      nama: item.nama || '',
      kode: item.kode || '',
      departemen: item.departemen || '',
      level_jabatan: item.level_jabatan || '',
      status: item.status || 'Aktif',
    });

    setModal(true);
  };

  const save = async (e: FormEvent) => {
    e.preventDefault();

    if (!form.nama.trim()) {
      alert('Nama jabatan wajib diisi.');
      return;
    }

    const payload = {
      nama: form.nama.trim(),
      kode: form.kode.trim() || null,
      departemen: form.departemen.trim() || null,
      level_jabatan: form.level_jabatan.trim() || null,
      status: form.status,
    };

    let error;

    if (editing) {
      ({ error } = await supabase
        .from('hris_jabatan')
        .update(payload)
        .eq('id', editing.id));
    } else {
      ({ error } = await supabase
        .from('hris_jabatan')
        .insert(payload));
    }

    if (error) {
      alert(`Gagal menyimpan jabatan:\n${error.message}`);
      return;
    }

    setModal(false);
    await load();
  };

  const remove = async (id: string) => {
    if (!confirm('Hapus jabatan ini?')) return;

    const { error } = await supabase
      .from('hris_jabatan')
      .delete()
      .eq('id', id);

    if (error) {
      alert(`Gagal menghapus:\n${error.message}`);
      return;
    }

    await load();
  };

  const filtered = data.filter((item) =>
    `${item.kode} ${item.nama} ${item.departemen} ${item.level_jabatan}`
      .toLowerCase()
      .includes(search.toLowerCase())
  );

  return (
    <>
      <SectionHeader
        title="Jabatan"
        description="Kelola jabatan dan level posisi karyawan."
        button="+ Tambah Jabatan"
        onClick={openAdd}
      />

      <div style={styles.toolbar}>
        <input
          style={styles.search}
          placeholder="Cari jabatan..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      <TableCard>
        <table style={styles.table}>
          <thead>
            <tr>
              <th>Kode</th>
              <th>Jabatan</th>
              <th>Departemen</th>
              <th>Level</th>
              <th>Status</th>
              <th>Aksi</th>
            </tr>
          </thead>

          <tbody>
            {loading ? (
              <EmptyRow text="Memuat data..." colSpan={6} />
            ) : filtered.length === 0 ? (
              <EmptyRow text="Belum ada jabatan." colSpan={6} />
            ) : (
              filtered.map((item) => (
                <tr key={item.id}>
                  <td>
                    <strong>{item.kode || '-'}</strong>
                  </td>

                  <td>{item.nama}</td>

                  <td>{item.departemen || '-'}</td>

                  <td>{item.level_jabatan || '-'}</td>

                  <td>
                    <StatusText value={item.status} />
                  </td>

                  <td>
                    <ActionButtons
                      onEdit={() => openEdit(item)}
                      onDelete={() => remove(item.id)}
                    />
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </TableCard>

      {modal && (
        <Modal
          title={editing ? 'Edit Jabatan' : 'Tambah Jabatan'}
          onClose={() => setModal(false)}
        >
          <form onSubmit={save}>
            <Input
              label="Kode Jabatan"
              value={form.kode}
              onChange={(v) => setForm({ ...form, kode: v })}
              placeholder="Contoh: SPV-WH"
            />

            <Input
              label="Nama Jabatan"
              value={form.nama}
              onChange={(v) => setForm({ ...form, nama: v })}
              placeholder="Contoh: Supervisor Warehouse"
              required
            />

            <Select
              label="Departemen"
              value={form.departemen}
              onChange={(v) => setForm({ ...form, departemen: v })}
              options={[
                '',
                ...departemen.map((item) => item.nama),
              ]}
            />

            <Input
              label="Level Jabatan"
              value={form.level_jabatan}
              onChange={(v) =>
                setForm({ ...form, level_jabatan: v })
              }
              placeholder="Contoh: Staff / Supervisor / Manager"
            />

            <Select
              label="Status"
              value={form.status}
              onChange={(v) => setForm({ ...form, status: v })}
              options={['Aktif', 'Nonaktif']}
            />

            <FormActions onCancel={() => setModal(false)} />
          </form>
        </Modal>
      )}
    </>
  );
}

/* =========================================================
   SHIFT
========================================================= */

function ShiftModule() {
  const [data, setData] = useState<Shift[]>([]);
  const [loading, setLoading] = useState(true);
  const [modal, setModal] = useState(false);
  const [editing, setEditing] = useState<Shift | null>(null);
  const [form, setForm] = useState(emptyShift);
  const [search, setSearch] = useState('');

  const load = async () => {
    setLoading(true);

    const { data, error } = await supabase
      .from('hris_shift')
      .select('*')
      .order('jam_masuk', { ascending: true });

    if (error) {
      alert(`Gagal mengambil shift:\n${error.message}`);
      setData([]);
    } else {
      setData((data || []) as Shift[]);
    }

    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const openAdd = () => {
    setEditing(null);
    setForm(emptyShift);
    setModal(true);
  };

  const openEdit = (item: Shift) => {
    setEditing(item);

    setForm({
      nama: item.nama || '',
      jam_masuk: item.jam_masuk
        ? String(item.jam_masuk).slice(0, 5)
        : '07:00',
      jam_pulang: item.jam_pulang
        ? String(item.jam_pulang).slice(0, 5)
        : '16:00',
      istirahat_menit: Number(item.istirahat_menit || 0),
      toleransi_menit: Number(item.toleransi_menit || 0),
      status: item.status || 'Aktif',
    });

    setModal(true);
  };

  const save = async (e: FormEvent) => {
    e.preventDefault();

    if (!form.nama.trim()) {
      alert('Nama shift wajib diisi.');
      return;
    }

    const payload = {
      nama: form.nama.trim(),
      jam_masuk: form.jam_masuk || null,
      jam_pulang: form.jam_pulang || null,
      istirahat_menit: Number(form.istirahat_menit || 0),
      toleransi_menit: Number(form.toleransi_menit || 0),
      status: form.status,
    };

    let error;

    if (editing) {
      ({ error } = await supabase
        .from('hris_shift')
        .update(payload)
        .eq('id', editing.id));
    } else {
      ({ error } = await supabase
        .from('hris_shift')
        .insert(payload));
    }

    if (error) {
      alert(`Gagal menyimpan shift:\n${error.message}`);
      return;
    }

    setModal(false);
    await load();
  };

  const remove = async (id: string) => {
    if (!confirm('Hapus shift ini?')) return;

    const { error } = await supabase
      .from('hris_shift')
      .delete()
      .eq('id', id);

    if (error) {
      alert(
        `Gagal menghapus shift.\n\n${error.message}\n\n`
        + 'Jika shift sudah digunakan pada jadwal, hapus atau pindahkan jadwal terlebih dahulu.'
      );
      return;
    }

    await load();
  };

  const filtered = data.filter((item) =>
    `${item.nama} ${item.jam_masuk} ${item.jam_pulang}`
      .toLowerCase()
      .includes(search.toLowerCase())
  );

  return (
    <>
      <SectionHeader
        title="Shift Kerja"
        description="Atur jam kerja, istirahat, dan toleransi keterlambatan."
        button="+ Tambah Shift"
        onClick={openAdd}
      />

      <div style={styles.toolbar}>
        <input
          style={styles.search}
          placeholder="Cari shift..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      <div style={styles.shiftGrid}>
        {loading ? (
          <div style={styles.loadingBox}>Memuat shift...</div>
        ) : filtered.length === 0 ? (
          <div style={styles.loadingBox}>Belum ada shift.</div>
        ) : (
          filtered.map((item) => (
            <div style={styles.shiftCard} key={item.id}>
              <div style={styles.shiftTop}>
                <div>
                  <div style={styles.shiftName}>{item.nama}</div>
                  <StatusText value={item.status} />
                </div>

                <div style={styles.clockIcon}>S</div>
              </div>

              <div style={styles.timeBox}>
                <div>
                  <span style={styles.miniLabel}>MASUK</span>
                  <strong>{formatTime(item.jam_masuk)}</strong>
                </div>

                <div style={styles.arrow}>→</div>

                <div>
                  <span style={styles.miniLabel}>PULANG</span>
                  <strong>{formatTime(item.jam_pulang)}</strong>
                </div>
              </div>

              <div style={styles.shiftInfo}>
                <span>Istirahat</span>
                <strong>{item.istirahat_menit || 0} menit</strong>
              </div>

              <div style={styles.shiftInfo}>
                <span>Toleransi</span>
                <strong>{item.toleransi_menit || 0} menit</strong>
              </div>

              <div style={styles.cardActions}>
                <button
                  type="button"
                  style={styles.secondaryButton}
                  onClick={() => openEdit(item)}
                >
                  Edit
                </button>

                <button
                  type="button"
                  style={styles.deleteButton}
                  onClick={() => remove(item.id)}
                >
                  Hapus
                </button>
              </div>
            </div>
          ))
        )}
      </div>

      {modal && (
        <Modal
          title={editing ? 'Edit Shift' : 'Tambah Shift'}
          onClose={() => setModal(false)}
        >
          <form onSubmit={save}>
            <Input
              label="Nama Shift"
              value={form.nama}
              onChange={(v) => setForm({ ...form, nama: v })}
              placeholder="Contoh: Shift Pagi"
              required
            />

            <div style={styles.formRow}>
              <TimeInput
                label="Jam Masuk"
                value={form.jam_masuk}
                onChange={(v) =>
                  setForm({ ...form, jam_masuk: v })
                }
              />

              <TimeInput
                label="Jam Pulang"
                value={form.jam_pulang}
                onChange={(v) =>
                  setForm({ ...form, jam_pulang: v })
                }
              />
            </div>

            <div style={styles.formRow}>
              <NumberInput
                label="Istirahat (menit)"
                value={form.istirahat_menit}
                onChange={(v) =>
                  setForm({
                    ...form,
                    istirahat_menit: Number(v),
                  })
                }
              />

              <NumberInput
                label="Toleransi (menit)"
                value={form.toleransi_menit}
                onChange={(v) =>
                  setForm({
                    ...form,
                    toleransi_menit: Number(v),
                  })
                }
              />
            </div>

            <Select
              label="Status"
              value={form.status}
              onChange={(v) => setForm({ ...form, status: v })}
              options={['Aktif', 'Nonaktif']}
            />

            <FormActions onCancel={() => setModal(false)} />
          </form>
        </Modal>
      )}
    </>
  );
}

/* =========================================================
   JADWAL
========================================================= */

function JadwalModule() {
  const [data, setData] = useState<Jadwal[]>([]);
  const [employees, setEmployees] = useState<Karyawan[]>([]);
  const [shifts, setShifts] = useState<Shift[]>([]);
  const [loading, setLoading] = useState(true);
  const [modal, setModal] = useState(false);
  const [editing, setEditing] = useState<Jadwal | null>(null);
  const [form, setForm] = useState(emptyJadwal);
  const [search, setSearch] = useState('');
  const [dateFilter, setDateFilter] = useState('');

  const load = async () => {
    setLoading(true);

    const [jadwalResult, employeeResult, shiftResult] =
      await Promise.all([
        supabase
          .from('hris_jadwal')
          .select('*')
          .order('tanggal', { ascending: false })
          .limit(500),

        supabase
          .from('karyawan')
          .select('id,id_karyawan,nama')
          .order('nama'),

        supabase
          .from('hris_shift')
          .select('*')
          .eq('status', 'Aktif')
          .order('jam_masuk'),
      ]);

    if (jadwalResult.error) {
      alert(`Gagal mengambil jadwal:\n${jadwalResult.error.message}`);
      setData([]);
    } else {
      setData((jadwalResult.data || []) as Jadwal[]);
    }

    if (employeeResult.error) {
      alert(
        `Gagal mengambil karyawan:\n${employeeResult.error.message}`
      );
      setEmployees([]);
    } else {
      setEmployees((employeeResult.data || []) as Karyawan[]);
    }

    if (shiftResult.error) {
      alert(`Gagal mengambil shift:\n${shiftResult.error.message}`);
      setShifts([]);
    } else {
      setShifts((shiftResult.data || []) as Shift[]);
    }

    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const openAdd = () => {
    setEditing(null);

    setForm({
      ...emptyJadwal,
      tanggal: dateFilter || new Date().toISOString().slice(0, 10),
      id_karyawan: employees[0]?.id_karyawan || '',
      shift_id: shifts[0]?.id || '',
    });

    setModal(true);
  };

  const openEdit = (item: Jadwal) => {
    setEditing(item);

    setForm({
      id_karyawan: item.id_karyawan || '',
      tanggal: item.tanggal || '',
      shift_id: item.shift_id || '',
      status: item.status || 'Terjadwal',
      catatan: item.catatan || '',
    });

    setModal(true);
  };

  const save = async (e: FormEvent) => {
    e.preventDefault();

    if (!form.id_karyawan) {
      alert('Karyawan wajib dipilih.');
      return;
    }

    if (!form.tanggal) {
      alert('Tanggal wajib diisi.');
      return;
    }

    if (!form.shift_id) {
      alert('Shift wajib dipilih.');
      return;
    }

    const payload = {
      id_karyawan: form.id_karyawan,
      tanggal: form.tanggal,
      shift_id: form.shift_id,
      status: form.status,
      catatan: form.catatan.trim() || null,
    };

    let error;

    if (editing) {
      ({ error } = await supabase
        .from('hris_jadwal')
        .update(payload)
        .eq('id', editing.id));
    } else {
      ({ error } = await supabase
        .from('hris_jadwal')
        .insert(payload));
    }

    if (error) {
      if (
        error.message.toLowerCase().includes('duplicate') ||
        error.message.toLowerCase().includes('unique')
      ) {
        alert(
          'Jadwal untuk karyawan tersebut pada tanggal itu sudah ada.'
        );
      } else {
        alert(`Gagal menyimpan jadwal:\n${error.message}`);
      }

      return;
    }

    setModal(false);
    await load();
  };

  const remove = async (id: string) => {
    if (!confirm('Hapus jadwal ini?')) return;

    const { error } = await supabase
      .from('hris_jadwal')
      .delete()
      .eq('id', id);

    if (error) {
      alert(`Gagal menghapus jadwal:\n${error.message}`);
      return;
    }

    await load();
  };

  const getEmployee = (idKaryawan: string) =>
    employees.find(
      (item) => item.id_karyawan === idKaryawan
    );

  const getShift = (shiftId: string | null) =>
    shifts.find((item) => item.id === shiftId);

  const filtered = data.filter((item) => {
    const employee = getEmployee(item.id_karyawan);
    const shift = getShift(item.shift_id);

    const text = [
      item.id_karyawan,
      employee?.nama,
      shift?.nama,
      item.status,
      item.catatan,
    ]
      .filter(Boolean)
      .join(' ')
      .toLowerCase();

    const matchSearch = text.includes(search.toLowerCase());

    const matchDate =
      !dateFilter || item.tanggal === dateFilter;

    return matchSearch && matchDate;
  });

  return (
    <>
      <SectionHeader
        title="Jadwal Karyawan"
        description="Atur jadwal kerja karyawan berdasarkan tanggal dan shift."
        button="+ Tambah Jadwal"
        onClick={openAdd}
      />

      <div style={styles.toolbar}>
        <input
          style={styles.search}
          placeholder="Cari nama atau ID karyawan..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />

        <input
          type="date"
          style={styles.dateFilter}
          value={dateFilter}
          onChange={(e) => setDateFilter(e.target.value)}
        />

        {dateFilter && (
          <button
            type="button"
            style={styles.clearButton}
            onClick={() => setDateFilter('')}
          >
            Reset
          </button>
        )}
      </div>

      <TableCard>
        <table style={styles.table}>
          <thead>
            <tr>
              <th>Tanggal</th>
              <th>Karyawan</th>
              <th>ID Karyawan</th>
              <th>Shift</th>
              <th>Jam</th>
              <th>Status</th>
              <th>Catatan</th>
              <th>Aksi</th>
            </tr>
          </thead>

          <tbody>
            {loading ? (
              <EmptyRow text="Memuat jadwal..." colSpan={8} />
            ) : filtered.length === 0 ? (
              <EmptyRow
                text="Belum ada jadwal."
                colSpan={8}
              />
            ) : (
              filtered.map((item) => {
                const employee = getEmployee(item.id_karyawan);
                const shift = getShift(item.shift_id);

                return (
                  <tr key={item.id}>
                    <td>
                      <strong>
                        {formatDate(item.tanggal)}
                      </strong>
                    </td>

                    <td>{employee?.nama || 'Karyawan tidak ditemukan'}</td>

                    <td>{item.id_karyawan}</td>

                    <td>{shift?.nama || '-'}</td>

                    <td>
                      {shift
                        ? `${formatTime(
                            shift.jam_masuk
                          )} - ${formatTime(
                            shift.jam_pulang
                          )}`
                        : '-'}
                    </td>

                    <td>
                      <StatusText value={item.status} />
                    </td>

                    <td>{item.catatan || '-'}</td>

                    <td>
                      <ActionButtons
                        onEdit={() => openEdit(item)}
                        onDelete={() => remove(item.id)}
                      />
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </TableCard>

      {modal && (
        <Modal
          title={editing ? 'Edit Jadwal' : 'Tambah Jadwal'}
          onClose={() => setModal(false)}
        >
          <form onSubmit={save}>
            <SelectWithLabels
              label="Karyawan"
              value={form.id_karyawan}
              onChange={(v) =>
                setForm({ ...form, id_karyawan: v })
              }
              options={employees.map((item) => ({
                value: item.id_karyawan,
                label: `${item.id_karyawan} — ${item.nama}`,
              }))}
            />

            <div style={styles.formRow}>
              <div style={{ flex: 1 }}>
                <label style={styles.label}>Tanggal</label>

                <input
                  type="date"
                  style={styles.input}
                  value={form.tanggal}
                  onChange={(e) =>
                    setForm({
                      ...form,
                      tanggal: e.target.value,
                    })
                  }
                  required
                />
              </div>

              <div style={{ flex: 1 }}>
                <Select
                  label="Shift"
                  value={form.shift_id}
                  onChange={(v) =>
                    setForm({
                      ...form,
                      shift_id: v,
                    })
                  }
                  options={shifts.map((item) => item.id)}
                  labels={Object.fromEntries(
                    shifts.map((item) => [
                      item.id,
                      `${item.nama} (${formatTime(
                        item.jam_masuk
                      )}-${formatTime(item.jam_pulang)})`,
                    ])
                  )}
                />
              </div>
            </div>

            <Select
              label="Status"
              value={form.status}
              onChange={(v) =>
                setForm({
                  ...form,
                  status: v,
                })
              }
              options={[
                'Terjadwal',
                'Hadir',
                'Libur',
                'Cuti',
                'Sakit',
                'Izin',
                'Tidak Hadir',
              ]}
            />

            <Textarea
              label="Catatan"
              value={form.catatan}
              onChange={(v) =>
                setForm({
                  ...form,
                  catatan: v,
                })
              }
              placeholder="Catatan jadwal..."
            />

            <FormActions onCancel={() => setModal(false)} />
          </form>
        </Modal>
      )}
    </>
  );
}

/* =========================================================
   REUSABLE COMPONENTS
========================================================= */

function SectionHeader({
  title,
  description,
  button,
  onClick,
}: {
  title: string;
  description: string;
  button: string;
  onClick: () => void;
}) {
  return (
    <div style={styles.sectionHeader}>
      <div>
        <h2 style={styles.sectionTitle}>{title}</h2>
        <p style={styles.sectionDescription}>{description}</p>
      </div>

      <button
        type="button"
        style={styles.primaryButton}
        onClick={onClick}
      >
        {button}
      </button>
    </div>
  );
}

function TableCard({ children }: { children: React.ReactNode }) {
  return (
    <div style={styles.tableCard}>{children}</div>
  );
}

function EmptyRow({
  text,
  colSpan,
}: {
  text: string;
  colSpan: number;
}) {
  return (
    <tr>
      <td
        colSpan={colSpan}
        style={styles.emptyCell}
      >
        {text}
      </td>
    </tr>
  );
}

function ActionButtons({
  onEdit,
  onDelete,
}: {
  onEdit: () => void;
  onDelete: () => void;
}) {
  return (
    <div style={styles.actionGroup}>
      <button
        type="button"
        style={styles.editButton}
        onClick={onEdit}
      >
        Edit
      </button>

      <button
        type="button"
        style={styles.deleteButton}
        onClick={onDelete}
      >
        Hapus
      </button>
    </div>
  );
}

function StatusBadge({ active }: { active: boolean }) {
  return (
    <span
      style={{
        ...styles.statusBadge,
        ...(active
          ? styles.statusActive
          : styles.statusInactive),
      }}
    >
      {active ? 'Aktif' : 'Nonaktif'}
    </span>
  );
}

function StatusText({ value }: { value: string }) {
  const active = value === 'Aktif' || value === 'Terjadwal';

  return (
    <span
      style={{
        ...styles.statusBadge,
        ...(active
          ? styles.statusActive
          : styles.statusInactive),
      }}
    >
      {value || '-'}
    </span>
  );
}

function Input({
  label,
  value,
  onChange,
  placeholder,
  required,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  required?: boolean;
}) {
  return (
    <div style={styles.field}>
      <label style={styles.label}>{label}</label>

      <input
        style={styles.input}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        required={required}
      />
    </div>
  );
}

function TimeInput({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <div style={{ flex: 1 }}>
      <label style={styles.label}>{label}</label>

      <input
        type="time"
        style={styles.input}
        value={value}
        onChange={(e) => onChange(e.target.value)}
      />
    </div>
  );
}

function NumberInput({
  label,
  value,
  onChange,
}: {
  label: string;
  value: number;
  onChange: (value: string) => void;
}) {
  return (
    <div style={{ flex: 1 }}>
      <label style={styles.label}>{label}</label>

      <input
        type="number"
        min="0"
        style={styles.input}
        value={value}
        onChange={(e) => onChange(e.target.value)}
      />
    </div>
  );
}

function Textarea({
  label,
  value,
  onChange,
  placeholder,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
}) {
  return (
    <div style={styles.field}>
      <label style={styles.label}>{label}</label>

      <textarea
        style={{
          ...styles.input,
          minHeight: 90,
          resize: 'vertical',
        }}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
      />
    </div>
  );
}

function Select({
  label,
  value,
  onChange,
  options,
  labels,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  options: string[];
  labels?: Record<string, string>;
}) {
  return (
    <div style={styles.field}>
      <label style={styles.label}>{label}</label>

      <select
        style={styles.input}
        value={value}
        onChange={(e) => onChange(e.target.value)}
      >
        {options.map((option) => (
          <option key={option} value={option}>
            {(labels?.[option] ?? option) || 'Pilih'}
          </option>
        ))}
      </select>
    </div>
  );
}

function SelectWithLabels({
  label,
  value,
  onChange,
  options,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  options: Array<{
    value: string;
    label: string;
  }>;
}) {
  return (
    <div style={styles.field}>
      <label style={styles.label}>{label}</label>

      <select
        style={styles.input}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        required
      >
        <option value="">Pilih karyawan...</option>

        {options.map((option) => (
          <option
            key={option.value}
            value={option.value}
          >
            {option.label}
          </option>
        ))}
      </select>
    </div>
  );
}

function Checkbox({
  label,
  checked,
  onChange,
}: {
  label: string;
  checked: boolean;
  onChange: (value: boolean) => void;
}) {
  return (
    <label style={styles.checkbox}>
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
      />

      <span>{label}</span>
    </label>
  );
}

function FormActions({
  onCancel,
}: {
  onCancel: () => void;
}) {
  return (
    <div style={styles.formActions}>
      <button
        type="button"
        style={styles.cancelButton}
        onClick={onCancel}
      >
        Batal
      </button>

      <button
        type="submit"
        style={styles.primaryButton}
      >
        Simpan
      </button>
    </div>
  );
}

function Modal({
  title,
  onClose,
  children,
}: {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
}) {
  return (
    <div style={styles.overlay}>
      <div style={styles.modal}>
        <div style={styles.modalHeader}>
          <h3 style={styles.modalTitle}>{title}</h3>

          <button
            type="button"
            style={styles.closeButton}
            onClick={onClose}
          >
            ×
          </button>
        </div>

        <div style={styles.modalBody}>{children}</div>
      </div>
    </div>
  );
}

/* =========================================================
   HELPERS
========================================================= */

function formatTime(value: string | null) {
  if (!value) return '--:--';

  return String(value).slice(0, 5);
}

function formatDate(value: string) {
  if (!value) return '-';

  const date = new Date(`${value}T00:00:00`);

  return date.toLocaleDateString('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });
}

/* =========================================================
   STYLES
========================================================= */

const styles: Record<string, React.CSSProperties> = {
  wrapper: {
    padding: '24px',
    width: '100%',
    boxSizing: 'border-box',
  },

  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: '24px',
  },

  eyebrow: {
    fontSize: '11px',
    fontWeight: 800,
    letterSpacing: '1.5px',
    color: '#64748b',
    marginBottom: '6px',
  },

  title: {
    margin: 0,
    fontSize: '30px',
    lineHeight: 1.2,
    fontWeight: 800,
    color: '#0f172a',
  },

  subtitle: {
    margin: '8px 0 0',
    color: '#64748b',
    fontSize: '14px',
  },

  tabs: {
    display: 'flex',
    gap: '8px',
    flexWrap: 'wrap',
    marginBottom: '24px',
    padding: '6px',
    background: '#f1f5f9',
    borderRadius: '14px',
  },

  tab: {
    border: 'none',
    background: 'transparent',
    color: '#64748b',
    padding: '11px 16px',
    borderRadius: '10px',
    fontWeight: 700,
    fontSize: '13px',
    cursor: 'pointer',
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
  },

  tabActive: {
    background: '#ffffff',
    color: '#0f172a',
    boxShadow: '0 2px 8px rgba(15,23,42,.08)',
  },

  sectionHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: '20px',
    marginBottom: '18px',
  },

  sectionTitle: {
    margin: 0,
    fontSize: '21px',
    fontWeight: 800,
    color: '#0f172a',
  },

  sectionDescription: {
    margin: '5px 0 0',
    color: '#64748b',
    fontSize: '13px',
  },

  primaryButton: {
    border: 'none',
    borderRadius: '10px',
    padding: '11px 16px',
    background: '#0f172a',
    color: '#ffffff',
    fontWeight: 700,
    cursor: 'pointer',
    fontSize: '13px',
  },

  secondaryButton: {
    border: '1px solid #cbd5e1',
    borderRadius: '8px',
    padding: '8px 12px',
    background: '#ffffff',
    color: '#334155',
    fontWeight: 700,
    cursor: 'pointer',
  },

  deleteButton: {
    border: '1px solid #fecaca',
    borderRadius: '8px',
    padding: '8px 12px',
    background: '#fff7f7',
    color: '#dc2626',
    fontWeight: 700,
    cursor: 'pointer',
  },

  editButton: {
    border: '1px solid #cbd5e1',
    borderRadius: '8px',
    padding: '8px 12px',
    background: '#ffffff',
    color: '#2563eb',
    fontWeight: 700,
    cursor: 'pointer',
  },

  cancelButton: {
    border: '1px solid #cbd5e1',
    borderRadius: '10px',
    padding: '11px 16px',
    background: '#ffffff',
    color: '#475569',
    fontWeight: 700,
    cursor: 'pointer',
  },

  toolbar: {
    display: 'flex',
    gap: '10px',
    alignItems: 'center',
    flexWrap: 'wrap',
    marginBottom: '14px',
  },

  search: {
    flex: 1,
    minWidth: '240px',
    border: '1px solid #dbe2ea',
    borderRadius: '10px',
    padding: '11px 13px',
    outline: 'none',
    fontSize: '13px',
    boxSizing: 'border-box',
  },

  dateFilter: {
    border: '1px solid #dbe2ea',
    borderRadius: '10px',
    padding: '11px 13px',
    fontSize: '13px',
  },

  clearButton: {
    border: '1px solid #dbe2ea',
    borderRadius: '10px',
    padding: '10px 13px',
    background: '#ffffff',
    cursor: 'pointer',
    fontWeight: 700,
    color: '#475569',
  },

  tableCard: {
    background: '#ffffff',
    border: '1px solid #e2e8f0',
    borderRadius: '14px',
    overflow: 'auto',
    boxShadow: '0 4px 16px rgba(15,23,42,.04)',
  },

  table: {
    width: '100%',
    borderCollapse: 'collapse',
    fontSize: '13px',
  },

  emptyCell: {
    padding: '40px 20px',
    textAlign: 'center',
    color: '#94a3b8',
  },

  actionGroup: {
    display: 'flex',
    gap: '6px',
    whiteSpace: 'nowrap',
  },

  statusBadge: {
    display: 'inline-flex',
    alignItems: 'center',
    padding: '5px 9px',
    borderRadius: '999px',
    fontSize: '11px',
    fontWeight: 800,
  },

  statusActive: {
    background: '#dcfce7',
    color: '#15803d',
  },

  statusInactive: {
    background: '#f1f5f9',
    color: '#64748b',
  },

  shiftGrid: {
    display: 'grid',
    gridTemplateColumns:
      'repeat(auto-fill, minmax(280px, 1fr))',
    gap: '16px',
  },

  shiftCard: {
    background: '#ffffff',
    border: '1px solid #e2e8f0',
    borderRadius: '16px',
    padding: '18px',
    boxShadow: '0 4px 16px rgba(15,23,42,.04)',
  },

  shiftTop: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: '16px',
  },

  shiftName: {
    fontSize: '17px',
    fontWeight: 800,
    color: '#0f172a',
    marginBottom: '8px',
  },

  clockIcon: {
    fontSize: '25px',
  },

  timeBox: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '14px',
    borderRadius: '12px',
    background: '#f8fafc',
    marginBottom: '12px',
  },

  timeBoxStrong: {
    fontWeight: 800,
  },

  miniLabel: {
    display: 'block',
    color: '#94a3b8',
    fontSize: '9px',
    fontWeight: 800,
    letterSpacing: '.7px',
    marginBottom: '4px',
  },

  arrow: {
    color: '#94a3b8',
    fontWeight: 800,
  },

  shiftInfo: {
    display: 'flex',
    justifyContent: 'space-between',
    padding: '8px 0',
    borderBottom: '1px solid #f1f5f9',
    fontSize: '12px',
    color: '#64748b',
  },

  cardActions: {
    display: 'flex',
    gap: '8px',
    marginTop: '14px',
  },

  loadingBox: {
    background: '#ffffff',
    border: '1px solid #e2e8f0',
    borderRadius: '14px',
    padding: '50px',
    textAlign: 'center',
    color: '#64748b',
  },

  field: {
    marginBottom: '15px',
  },

  label: {
    display: 'block',
    fontSize: '12px',
    fontWeight: 800,
    color: '#334155',
    marginBottom: '6px',
  },

  input: {
    width: '100%',
    boxSizing: 'border-box',
    border: '1px solid #dbe2ea',
    borderRadius: '9px',
    padding: '10px 12px',
    outline: 'none',
    fontSize: '13px',
    background: '#ffffff',
    color: '#0f172a',
  },

  formRow: {
    display: 'flex',
    gap: '12px',
    marginBottom: '15px',
  },

  checkbox: {
    display: 'flex',
    gap: '8px',
    alignItems: 'center',
    marginBottom: '18px',
    fontSize: '13px',
    color: '#334155',
    fontWeight: 600,
  },

  formActions: {
    display: 'flex',
    justifyContent: 'flex-end',
    gap: '8px',
    paddingTop: '12px',
    marginTop: '8px',
    borderTop: '1px solid #e2e8f0',
  },

  overlay: {
    position: 'fixed',
    inset: 0,
    background: 'rgba(15,23,42,.55)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    padding: '20px',
    zIndex: 9999,
  },

  modal: {
    width: '100%',
    maxWidth: '560px',
    maxHeight: '90vh',
    overflow: 'auto',
    background: '#ffffff',
    borderRadius: '16px',
    boxShadow: '0 25px 60px rgba(15,23,42,.25)',
  },

  modalHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '18px 20px',
    borderBottom: '1px solid #e2e8f0',
  },

  modalTitle: {
    margin: 0,
    fontSize: '18px',
    fontWeight: 800,
    color: '#0f172a',
  },

  closeButton: {
    width: '32px',
    height: '32px',
    border: 'none',
    borderRadius: '8px',
    background: '#f1f5f9',
    color: '#475569',
    fontSize: '22px',
    cursor: 'pointer',
  },

  modalBody: {
    padding: '20px',
  },
};

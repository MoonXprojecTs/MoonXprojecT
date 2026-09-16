import RegistrasiKaryawan from '../../components/karyawan/profile/RegistrasiKaryawan';

interface EmployeeRegisterProps {
  onBack: () => void;
}

export default function EmployeeRegister({
  onBack,
}: EmployeeRegisterProps) {
  return (
    <RegistrasiKaryawan
      onBack={onBack}
    />
  );
}

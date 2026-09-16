import { Component, type ErrorInfo, type ReactNode } from 'react';

type Props = { children: ReactNode };
type State = { hasError: boolean; message: string };

export default class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false, message: '' };

  static getDerivedStateFromError(error: unknown): State {
    return { hasError: true, message: error instanceof Error ? error.message : 'Terjadi kesalahan pada aplikasi.' };
  }

  componentDidCatch(error: unknown, info: ErrorInfo) {
    console.error('MoonXprojecT runtime error', error, info.componentStack);
  }

  render() {
    if (!this.state.hasError) return this.props.children;
    return (
      <main className="runtime-error" role="alert">
        <div className="runtime-error-card">
          <span className="eyebrow">MOONXPROJECT</span>
          <h1>Terjadi gangguan sementara</h1>
          <p>{this.state.message}</p>
          <button className="primary" onClick={() => window.location.reload()}>Muat ulang aplikasi</button>
        </div>
      </main>
    );
  }
}

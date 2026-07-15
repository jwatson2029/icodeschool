import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'iCodeSchool — Screen Lock Dashboard',
  description: 'Admin dashboard for classroom screen locking',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}

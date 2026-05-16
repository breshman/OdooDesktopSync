import { useState } from 'react';
import {
  LayoutDashboard,
  FileSpreadsheet,
  LogOut,
  Server,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Separator } from '@/components/ui/separator';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import ExcelPage from './pages/ExcelPage';

function App() {
  const [user, setUser] = useState(null);
  const [activeTab, setActiveTab] = useState('dashboard');

  if (!user) {
    return <LoginPage onLogin={(data) => setUser(data)} />;
  }

  return (
    <div className="flex h-screen bg-background">
      {/* Sidebar */}
      <aside className="w-56 min-w-56 border-r border-border bg-sidebar flex flex-col">
        <div className="flex items-center gap-2.5 px-5 py-5">
          <Server size={20} className="text-primary" />
          <span className="text-base font-bold text-foreground">OdooSync</span>
        </div>

        <Separator />

        <nav className="flex-1 flex flex-col gap-1 p-2.5">
          <Button
            variant={activeTab === 'dashboard' ? 'secondary' : 'ghost'}
            className="justify-start gap-2.5 w-full"
            onClick={() => setActiveTab('dashboard')}
          >
            <LayoutDashboard size={18} />
            Dashboard
          </Button>
          <Button
            variant={activeTab === 'excel' ? 'secondary' : 'ghost'}
            className="justify-start gap-2.5 w-full"
            onClick={() => setActiveTab('excel')}
          >
            <FileSpreadsheet size={18} />
            Excel
          </Button>
        </nav>

        <Separator />

        <div className="p-3 flex items-center gap-2">
          <Avatar className="h-8 w-8">
            <AvatarFallback className="text-xs font-bold">
              {(user.username || 'U')[0].toUpperCase()}
            </AvatarFallback>
          </Avatar>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-semibold text-foreground truncate">
              {user.username || 'Usuario'}
            </p>
            <p className="text-[11px] text-muted-foreground truncate">
              {user.url}
            </p>
          </div>
          <Button
            variant="ghost"
            size="icon"
            className="h-8 w-8 text-muted-foreground hover:text-destructive"
            onClick={() => setUser(null)}
          >
            <LogOut size={16} />
          </Button>
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-hidden">
        {activeTab === 'dashboard' && <DashboardPage />}
        {activeTab === 'excel' && <ExcelPage />}
      </main>
    </div>
  );
}

export default App;

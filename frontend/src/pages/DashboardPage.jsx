import { useState, useEffect } from 'react';
import {
  LayoutDashboard,
  FolderOpen,
  FileSpreadsheet,
  Activity,
  CheckCircle,
} from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';
import { getConfig, loadItems } from '../services/api';

export default function DashboardPage() {
  const [stats, setStats] = useState({
    totalPaths: 0,
    activePaths: 0,
    totalRecords: 0,
    apis: [],
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      setLoading(true);
      try {
        const [configRes, itemsRes] = await Promise.allSettled([
          getConfig(),
          loadItems(),
        ]);

        const config = configRes.status === 'fulfilled' ? configRes.value.data : {};
        const items = itemsRes.status === 'fulfilled' ? itemsRes.value.data : [];

        setStats({
          totalPaths: (config.config_paths || []).length,
          activePaths: (config.config_paths || []).filter((p) => p.is_active).length,
          totalRecords: items.length,
          apis: config.api || [],
        });
      } catch {
        // silently fail
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full text-muted-foreground gap-3">
        <span className="h-5 w-5 border-2 border-muted-foreground/20 border-t-muted-foreground rounded-full animate-spin" />
        Cargando métricas...
      </div>
    );
  }

  return (
    <div className="p-8 overflow-y-auto h-full">
      <div className="flex items-center gap-3 mb-7">
        <LayoutDashboard size={22} className="text-primary" />
        <h2 className="text-xl font-bold">Dashboard</h2>
      </div>

      <div className="grid grid-cols-3 gap-5 mb-8">
        <Card className="overflow-hidden">
          <CardContent className="flex items-center gap-4 p-5">
            <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-blue-500/10 text-blue-400">
              <FolderOpen size={24} />
            </div>
            <div>
              <p className="text-3xl font-bold">{stats.activePaths}/{stats.totalPaths}</p>
              <p className="text-sm text-muted-foreground">Rutas Activas</p>
            </div>
          </CardContent>
        </Card>

        <Card className="overflow-hidden">
          <CardContent className="flex items-center gap-4 p-5">
            <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-emerald-500/10 text-emerald-400">
              <FileSpreadsheet size={24} />
            </div>
            <div>
              <p className="text-3xl font-bold">{stats.totalRecords}</p>
              <p className="text-sm text-muted-foreground">Registros Disponibles</p>
            </div>
          </CardContent>
        </Card>

        <Card className="overflow-hidden">
          <CardContent className="flex items-center gap-4 p-5">
            <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-amber-500/10 text-amber-400">
              <Activity size={24} />
            </div>
            <div>
              <p className="text-3xl font-bold">{stats.apis.length}</p>
              <p className="text-sm text-muted-foreground">Endpoints API</p>
            </div>
          </CardContent>
        </Card>
      </div>

      <Separator className="mb-6" />

      <div>
        <h3 className="text-base font-semibold mb-4">Endpoints Configurados</h3>
        <div className="flex flex-col gap-2">
          {stats.apis.length === 0 ? (
            <p className="text-muted-foreground text-sm">No hay endpoints configurados.</p>
          ) : (
            stats.apis.map((a, i) => (
              <Card key={i}>
                <CardContent className="flex items-center gap-3 p-4">
                  <CheckCircle size={16} className="text-emerald-400 flex-shrink-0" />
                  <span className="text-sm font-semibold">{a.name}</span>
                  <Badge variant="secondary" className="font-mono text-xs">{a.url}</Badge>
                </CardContent>
              </Card>
            ))
          )}
        </div>
      </div>
    </div>
  );
}

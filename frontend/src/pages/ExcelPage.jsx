import { useState, useEffect, useCallback } from 'react';
import {
  FileSpreadsheet,
  Send,
  RefreshCw,
  CheckSquare,
  Square,
  Search,
  ChevronLeft,
  ChevronRight,
  FolderOpen,
  Plus,
  Settings,
  X,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Switch } from '@/components/ui/switch';
import { Badge } from '@/components/ui/badge';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Separator } from '@/components/ui/separator';
import { toast } from 'sonner';
import { loadItems, sendItems, getConfig, addOrUpdatePath } from '../services/api';

const PAGE_SIZE = 20;

export default function ExcelPage() {
  const [items, setItems] = useState([]);
  const [filteredItems, setFilteredItems] = useState([]);
  const [selectedIds, setSelectedIds] = useState(new Set());
  const [searchTerm, setSearchTerm] = useState('');
  const [loading, setLoading] = useState(false);
  const [sending, setSending] = useState(false);
  const [page, setPage] = useState(0);
  const [paths, setPaths] = useState([]);
  const [showPathModal, setShowPathModal] = useState(false);
  const [newPath, setNewPath] = useState('');

  // Load config paths on mount
  useEffect(() => {
    getConfig()
      .then((res) => setPaths(res.data.config_paths || []))
      .catch(() => {});
  }, []);

  // Load items from backend
  const handleLoad = useCallback(async () => {
    setLoading(true);
    try {
      const res = await loadItems();
      setItems(res.data);
      setSelectedIds(new Set());
      setPage(0);
      toast.success(`${res.data.length} registros cargados`);
    } catch {
      toast.error('Error al cargar archivos');
    } finally {
      setLoading(false);
    }
  }, []);

  // Filter items when search changes
  useEffect(() => {
    if (!searchTerm.trim()) {
      setFilteredItems(items);
    } else {
      const q = searchTerm.toLowerCase();
      setFilteredItems(
        items.filter(
          (i) =>
            i.codigo?.toLowerCase().includes(q) ||
            i.descripcion?.toLowerCase().includes(q)
        )
      );
    }
    setPage(0);
  }, [searchTerm, items]);

  // Pagination
  const totalPages = Math.max(1, Math.ceil(filteredItems.length / PAGE_SIZE));
  const pagedItems = filteredItems.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE);

  // Selection
  const toggleSelect = (index) => {
    const globalIndex = page * PAGE_SIZE + index;
    setSelectedIds((prev) => {
      const next = new Set(prev);
      next.has(globalIndex) ? next.delete(globalIndex) : next.add(globalIndex);
      return next;
    });
  };
  const selectAll = () => {
    const start = page * PAGE_SIZE;
    const end = Math.min(start + PAGE_SIZE, filteredItems.length);
    setSelectedIds((prev) => {
      const next = new Set(prev);
      for (let i = start; i < end; i++) next.add(i);
      return next;
    });
  };
  const deselectAll = () => {
    const start = page * PAGE_SIZE;
    const end = Math.min(start + PAGE_SIZE, filteredItems.length);
    setSelectedIds((prev) => {
      const next = new Set(prev);
      for (let i = start; i < end; i++) next.delete(i);
      return next;
    });
  };

  // Send
  const handleSend = async () => {
    const selected = filteredItems.filter((_, i) => selectedIds.has(i));
    if (selected.length === 0) {
      toast.error('Selecciona al menos un registro');
      return;
    }
    setSending(true);
    try {
      await sendItems(selected);
      toast.success(`${selected.length} registros enviados correctamente`);
    } catch {
      toast.error('Error al enviar registros');
    } finally {
      setSending(false);
    }
  };

  // Toggle path active/inactive
  const togglePath = async (p) => {
    try {
      const updated = { path: p.path, is_active: !p.is_active };
      await addOrUpdatePath(updated);
      setPaths((prev) =>
        prev.map((x) => (x.path === p.path ? { ...x, is_active: !x.is_active } : x))
      );
    } catch {
      toast.error('Error al actualizar ruta');
    }
  };

  // Add new path
  const handleAddPath = async () => {
    if (!newPath.trim()) return;
    try {
      const res = await addOrUpdatePath({ path: newPath, is_active: true });
      setPaths(res.data.config_paths || []);
      setNewPath('');
      toast.success('Ruta agregada');
    } catch {
      toast.error('Error al agregar ruta');
    }
  };

  const allPageSelected = pagedItems.length > 0 &&
    pagedItems.every((_, i) => selectedIds.has(page * PAGE_SIZE + i));

  return (
    <div className="flex flex-col h-full">
      {/* Toolbar */}
      <div className="flex items-center gap-3 px-5 py-3 border-b border-border bg-sidebar shrink-0">
        <div className="flex items-center gap-2">
          <Button variant="outline" size="icon" onClick={() => setShowPathModal(true)} title="Configurar rutas">
            <Settings size={16} />
          </Button>
          <Button variant="outline" onClick={handleLoad} disabled={loading}>
            {loading ? (
              <span className="h-4 w-4 border-2 border-muted-foreground/20 border-t-muted-foreground rounded-full animate-spin" />
            ) : (
              <RefreshCw size={14} />
            )}
            {loading ? 'Cargando...' : 'Cargar Excel'}
          </Button>
        </div>

        <div className="flex-1 max-w-sm">
          <div className="relative">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
            <Input
              type="text"
              placeholder="Buscar por código o descripción..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-8 h-9 text-sm"
            />
          </div>
        </div>

        <div className="flex items-center gap-3 ml-auto">
          <Badge variant="secondary">{selectedIds.size} seleccionados</Badge>
          <Button onClick={handleSend} disabled={sending || selectedIds.size === 0}>
            {sending ? (
              <span className="h-4 w-4 border-2 border-white/20 border-t-white rounded-full animate-spin" />
            ) : (
              <Send size={14} />
            )}
            Enviar a Odoo
          </Button>
        </div>
      </div>

      {/* Path config dialog */}
      <Dialog open={showPathModal} onOpenChange={setShowPathModal}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <FolderOpen size={18} /> Rutas de archivos Excel
            </DialogTitle>
          </DialogHeader>
          <div className="flex flex-col gap-3 mt-2">
            {paths.map((p, i) => (
              <div key={i} className="flex items-center gap-3 rounded-md border border-border bg-muted/30 px-4 py-3">
                <Switch
                  checked={p.is_active}
                  onCheckedChange={() => togglePath(p)}
                />
                <span className={`text-sm font-mono font-medium ${!p.is_active ? 'text-muted-foreground line-through' : 'text-foreground'}`}>
                  {p.path}
                </span>
              </div>
            ))}
            <Separator />
            <div className="flex gap-2">
              <Input
                type="text"
                placeholder="Nueva ruta (ej: C:/excel_3)"
                value={newPath}
                onChange={(e) => setNewPath(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleAddPath()}
                className="h-9 text-sm"
              />
              <Button variant="outline" onClick={handleAddPath}>
                <Plus size={14} /> Agregar
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* Data Table */}
      <div className="flex-1 overflow-auto">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="w-12 text-center">
                <button
                  className="text-muted-foreground hover:text-foreground transition-colors"
                  onClick={allPageSelected ? deselectAll : selectAll}
                >
                  {allPageSelected ? <CheckSquare size={16} /> : <Square size={16} />}
                </button>
              </TableHead>
              <TableHead>Código</TableHead>
              <TableHead>Descripción</TableHead>
              <TableHead className="text-right">Cantidad</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {pagedItems.length === 0 ? (
              <TableRow>
                <TableCell colSpan={4} className="text-center py-16 text-muted-foreground">
                  <FileSpreadsheet size={36} className="mx-auto opacity-30 mb-3" />
                  <p className="text-sm">No hay datos. Presiona "Cargar Excel" para comenzar.</p>
                </TableCell>
              </TableRow>
            ) : (
              pagedItems.map((item, i) => {
                const globalIndex = page * PAGE_SIZE + i;
                const isSelected = selectedIds.has(globalIndex);
                return (
                  <TableRow
                    key={globalIndex}
                    className={`cursor-pointer ${isSelected ? 'bg-primary/5' : ''}`}
                    onClick={() => toggleSelect(i)}
                  >
                    <TableCell className="text-center">
                      {isSelected ? (
                        <CheckSquare size={16} className="text-primary mx-auto" />
                      ) : (
                        <Square size={16} className="text-muted-foreground mx-auto" />
                      )}
                    </TableCell>
                    <TableCell className="font-mono text-xs font-semibold">{item.codigo}</TableCell>
                    <TableCell>{item.descripcion}</TableCell>
                    <TableCell className="text-right font-mono text-xs">{item.cantidad}</TableCell>
                  </TableRow>
                );
              })
            )}
          </TableBody>
        </Table>
      </div>

      {/* Pagination */}
      {filteredItems.length > PAGE_SIZE && (
        <div className="flex items-center justify-center gap-4 py-3 border-t border-border bg-sidebar shrink-0">
          <Button variant="outline" size="icon" className="h-8 w-8" disabled={page === 0} onClick={() => setPage(page - 1)}>
            <ChevronLeft size={14} />
          </Button>
          <span className="text-sm text-muted-foreground">Página {page + 1} de {totalPages}</span>
          <Button variant="outline" size="icon" className="h-8 w-8" disabled={page >= totalPages - 1} onClick={() => setPage(page + 1)}>
            <ChevronRight size={14} />
          </Button>
        </div>
      )}
    </div>
  );
}

import axios from 'axios';

const API_BASE = 'http://localhost:8080';

const api = axios.create({
  baseURL: API_BASE,
  headers: {
    'Content-Type': 'application/json',
  },
});

// ---- Items API ----
export const loadItems = () => api.get('/api/items');
export const sendItems = (items) => api.post('/api/items/send', items);

// ---- Config API ----
export const getConfig = () => api.get('/api/config');
export const updateFullConfig = (config) => api.put('/api/config', config);
export const addOrUpdateApi = (apiConfig) => api.post('/api/config/api', apiConfig);
export const addOrUpdatePath = (pathConfig) => api.post('/api/config/paths', pathConfig);

export default api;

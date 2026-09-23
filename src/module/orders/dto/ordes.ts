export interface OrderItemResponse {
  id: number;
  producto_id: number;
  codigo: string;
  producto: string;
  cantidad: number;
  precio_unitario: number;
  subtotal: number;
}

export interface OrderResponse {
  id: number;
  numero: string;
  cliente_id?: number;
  cliente: string;
  estado: string;
  subtotal: number;
  descuento: number;
  total: number;
  descuento_porcentaje?: number;
  fecha_creacion: string;
  items: OrderItemResponse[];
}

export interface OrderListResponse {
  id: number;
  numero: string;
  cliente: string;
  estado: string;
  subtotal: number;
  descuento: number;
  total: number;
  fecha_creacion: string;
}

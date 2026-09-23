import { Injectable } from '@nestjs/common';
import { ResponseServer } from 'src/shared/interface/ResponseServer.interface';
import { OrderListResponse, OrderResponse } from './dto/ordes';
import { DatabaseService } from 'src/shared/database/database.service';
import { AddOrderItemRequest, CreateOrderRequest, OrderListRequest } from './dto/create-order.dto';
import { Pool, PoolClient } from 'pg';
@Injectable()
export class OrdersService {
  private pool: Pool;

  constructor(private readonly databaseService: DatabaseService) {
    this.pool = databaseService.getPool();
  }

  async create(
    request: CreateOrderRequest,
  ): Promise<ResponseServer<OrderResponse>> {
    let client: PoolClient | null = null;

    try {
      client = await this.pool.connect();

      const query = `
                SELECT public.crear_pedido_v1($1, $2) AS data;
            `;

      const result = await client.query(query, [
        request.cliente_id,
        request.descuento_porcentaje ?? 0,
      ]);

      return {
        status: true,
        message: 'Pedido creado correctamente.',
        data: result.rows[0].data,
      };
    } catch (error) {
      return {
        status: false,
        message: error instanceof Error ? error.message : 'Error interno',
      };
    } finally {
      if (client) {
        client.release();
      }
    }
  }

  async findAll(
    request: OrderListRequest,
  ): Promise<ResponseServer<OrderListResponse[]>> {
    let client: PoolClient | null = null;

    try {
      client = await this.pool.connect();

      const query = `
                SELECT *
                FROM public.obtener_pedidos_v1($1, $2);
            `;

      const result = await client.query(query, [
        request.estado ?? null,
        request.cliente_id ?? null,
      ]);

      return {
        status: true,
        message: 'Pedidos obtenidos correctamente.',
        data: result.rows,
      };
    } catch (error) {
      return {
        status: false,
        message: error instanceof Error ? error.message : 'Error interno',
      };
    } finally {
      if (client) {
        client.release();
      }
    }
  }

  async findById(id: number): Promise<ResponseServer<OrderResponse>> {
    let client: PoolClient | null = null;

    try {
      client = await this.pool.connect();

      const query = `
                SELECT public.obtener_pedido_v1($1) AS data;
            `;

      const result = await client.query(query, [id]);

      if (!result.rows[0]?.data) {
        return {
          status: false,
          message: 'Pedido no encontrado.',
        };
      }

      return {
        status: true,
        message: 'Pedido obtenido correctamente.',
        data: result.rows[0].data,
      };
    } catch (error) {
      return {
        status: false,
        message: error instanceof Error ? error.message : 'Error interno',
      };
    } finally {
      if (client) {
        client.release();
      }
    }
  }

  async addItem(
    pedidoId: number,
    request: AddOrderItemRequest,
  ): Promise<ResponseServer<OrderResponse>> {
    let client: PoolClient | null = null;

    try {
      client = await this.pool.connect();

      const query = `
                SELECT public.agregar_item_pedido_v1($1, $2, $3) AS data;
            `;

      const result = await client.query(query, [
        pedidoId,
        request.producto_id,
        request.cantidad,
      ]);

      return {
        status: true,
        message: 'Producto agregado al pedido correctamente.',
        data: result.rows[0].data,
      };
    } catch (error) {
      return {
        status: false,
        message: error instanceof Error ? error.message : 'Error interno',
      };
    } finally {
      if (client) {
        client.release();
      }
    }
  }

  async deleteItem(
    pedidoId: number,
    itemId: number,
  ): Promise<ResponseServer<OrderResponse>> {
    let client: PoolClient | null = null;

    try {
      client = await this.pool.connect();

      const query = `
                SELECT public.eliminar_item_pedido_v1($1, $2) AS data;
            `;

      const result = await client.query(query, [pedidoId, itemId]);

      return {
        status: true,
        message: 'Producto eliminado del pedido correctamente.',
        data: result.rows[0].data,
      };
    } catch (error) {
      return {
        status: false,
        message: error instanceof Error ? error.message : 'Error interno',
      };
    } finally {
      if (client) {
        client.release();
      }
    }
  }

  async confirm(id: number): Promise<ResponseServer<OrderResponse>> {
    let client: PoolClient | null = null;

    try {
      client = await this.pool.connect();

      const query = `
                SELECT public.confirmar_pedido_v1($1) AS data;
            `;

      const result = await client.query(query, [id]);

      return {
        status: true,
        message: 'Pedido confirmado correctamente.',
        data: result.rows[0].data,
      };
    } catch (error) {
      return {
        status: false,
        message: error instanceof Error ? error.message : 'Error interno',
      };
    } finally {
      if (client) {
        client.release();
      }
    }
  }

  async complete(id: number): Promise<ResponseServer<OrderResponse>> {
    let client: PoolClient | null = null;

    try {
      client = await this.pool.connect();

      const query = `
                SELECT public.completar_pedido_v1($1) AS data;
            `;

      const result = await client.query(query, [id]);

      return {
        status: true,
        message: 'Pedido completado correctamente.',
        data: result.rows[0].data,
      };
    } catch (error) {
      return {
        status: false,
        message: error instanceof Error ? error.message : 'Error interno',
      };
    } finally {
      if (client) {
        client.release();
      }
    }
  }

  async cancel(id: number): Promise<ResponseServer<OrderResponse>> {
    let client: PoolClient | null = null;

    try {
      client = await this.pool.connect();

      const query = `
                SELECT public.cancelar_pedido_v1($1) AS data;
            `;

      const result = await client.query(query, [id]);

      return {
        status: true,
        message: 'Pedido cancelado correctamente.',
        data: result.rows[0].data,
      };
    } catch (error) {
      return {
        status: false,
        message: error instanceof Error ? error.message : 'Error interno',
      };
    } finally {
      if (client) {
        client.release();
      }
    }
  }
}

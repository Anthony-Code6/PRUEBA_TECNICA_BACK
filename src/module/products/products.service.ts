import { Injectable } from '@nestjs/common';
import {
  CreateProductRequest,
  ProductListRequest,
} from './dto/create-product.dto';
import { ResponseServer } from 'src/shared/interface/ResponseServer.interface';
import { ProductResponse } from './dto/producto';
import { Pool, PoolClient } from 'pg';
import { DatabaseService } from 'src/shared/database/database.service';
@Injectable()
export class ProductsService {
  private pool: Pool;

  constructor(private readonly databaseService: DatabaseService) {
    this.pool = databaseService.getPool();
  }

  async create(
    request: CreateProductRequest,
  ): Promise<ResponseServer<ProductResponse>> {
    let client: PoolClient | null = null;

    try {
      client = await this.pool.connect();

      const query = `
                SELECT public.crear_producto_v1($1, $2, $3, $4) AS data;
            `;

      const result = await client.query(query, [
        request.codigo,
        request.nombre,
        request.precio,
        request.stock,
      ]);

      return {
        status: true,
        message: 'Producto creado correctamente.',
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
    request: ProductListRequest,
  ): Promise<ResponseServer<ProductResponse[]>> {
    let client: PoolClient | null = null;

    try {
      client = await this.pool.connect();

      const query = `
                SELECT *
                FROM public.obtener_productos_v1($1, $2);
            `;

      const result = await client.query(query, [
        request.nombre ?? null,
        request.codigo ?? null,
      ]);

      return {
        status: true,
        message: 'Productos obtenidos correctamente.',
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
}

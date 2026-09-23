import { Injectable } from '@nestjs/common';
import { Pool, PoolClient } from 'pg';
import { DatabaseService } from 'src/shared/database/database.service';
import { CreateCustomerRequest, CustomerListRequest } from './dto/create-customer.dto';
import { ResponseServer } from 'src/shared/interface/ResponseServer.interface';
import { CustomerResponse } from './dto/customer';

@Injectable()
export class CustomersService {
  private pool: Pool;

  constructor(private readonly databaseService: DatabaseService) {
    this.pool = databaseService.getPool();
  }

  async create(
    request: CreateCustomerRequest,
  ): Promise<ResponseServer<CustomerResponse>> {
    let client: PoolClient | null = null;

    try {
      client = await this.pool.connect();

      const query = `
                SELECT public.crear_cliente_v1($1, $2, $3) AS data;
            `;

      const result = await client.query(query, [
        request.nombre,
        request.documento,
        request.email ?? null,
      ]);

      return {
        status: true,
        message: 'Cliente creado correctamente.',
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
    request: CustomerListRequest,
  ): Promise<ResponseServer<CustomerResponse[]>> {
    let client: PoolClient | null = null;

    try {
      client = await this.pool.connect();

      const query = `
                SELECT *
                FROM public.obtener_clientes_v1($1, $2);
            `;

      const result = await client.query(query, [
        request.nombre ?? null,
        request.documento ?? null,
      ]);

      return {
        status: true,
        message: 'Clientes obtenidos correctamente.',
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

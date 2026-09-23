import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Pool } from 'pg';

@Injectable()
export class DatabaseService implements OnModuleInit {
  private pool: Pool;

  constructor(private configService: ConfigService) {
    this.pool = new Pool({
      host: this.configService.get<string>('DB_HOST'),
      user: this.configService.get<string>('DB_USER'),
      password: this.configService.get<string>('DB_PASSWORD'),
      database: this.configService.get<string>('DB_NAME'),
      port: Number(this.configService.get<string>('DB_PORT')),
      ssl:
        this.configService.get<string>('DB_SSL') === 'true'
          ? { rejectUnauthorized: false }
          : undefined,
    });

    this.pool.on('error', (err) => {
      console.error('❌ Error inesperado en PostgreSQL:', err);
    });
  }

  async onModuleInit() {
    try {
      const client = await this.pool.connect();

      await client.query('SET search_path TO public');

      const result = await client.query('SHOW search_path');
      // console.log('📌 search_path:', result.rows[0].search_path);

      client.release();
    } catch (error) {
      console.error('❌ Error conectando a la base de datos:', error);
    }
  }

  getPool(): Pool {
    return this.pool;
  }
}

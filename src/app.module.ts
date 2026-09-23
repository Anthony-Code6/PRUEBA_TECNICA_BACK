import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { DatabaseModule } from './shared/database/database.module';
import { CustomersModule } from './module/customers/customers.module';
import { OrdersModule } from './module/orders/orders.module';
import { ProductsModule } from './module/products/products.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    DatabaseModule,
    CustomersModule,
    OrdersModule,
    ProductsModule,
  ],
})
export class AppModule {}

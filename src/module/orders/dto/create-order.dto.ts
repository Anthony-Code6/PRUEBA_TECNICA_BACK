import { IsInt, IsNumber, IsOptional, Max, Min } from 'class-validator';

export class CreateOrderRequest {
  @IsInt()
  @Min(1)
  cliente_id: number;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(100)
  descuento_porcentaje?: number;
}

export class AddOrderItemRequest {
  @IsInt()
  @Min(1)
  producto_id: number;

  @IsInt()
  @Min(1)
  cantidad: number;
}

export class OrderListRequest {
  @IsOptional()
  // @IsIn(['PENDIENTE', 'CONFIRMADO', 'CANCELADO', 'COMPLETADO'])
  estado?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  cliente_id?: number;
}

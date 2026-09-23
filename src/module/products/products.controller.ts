import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  Query,
} from '@nestjs/common';
import { ProductsService } from './products.service';
import {
  CreateProductRequest,
  ProductListRequest,
} from './dto/create-product.dto';

@Controller('products')
export class ProductsController {
  constructor(private readonly productsService: ProductsService) {}

  @Post()
  create(@Body() request: CreateProductRequest) {
    return this.productsService.create(request);
  }

  @Get()
  findAll(@Query() request: ProductListRequest) {
    return this.productsService.findAll(request);
  }
}

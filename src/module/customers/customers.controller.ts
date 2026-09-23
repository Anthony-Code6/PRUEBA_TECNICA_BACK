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
import { CustomersService } from './customers.service';
import {
  CreateCustomerRequest,
  CustomerListRequest,
} from './dto/create-customer.dto';

@Controller('customers')
export class CustomersController {
  constructor(private readonly customersService: CustomersService) {}

  @Post()
  create(@Body() request: CreateCustomerRequest) {
    return this.customersService.create(request);
  }

  @Get()
  findAll(@Query() request: CustomerListRequest) {
    return this.customersService.findAll(request);
  }
}

// src/Filters/validation-exception.filter.ts
import {
  Catch,
  ArgumentsHost,
  ExceptionFilter,
  BadRequestException,
} from '@nestjs/common';

@Catch(BadRequestException)
export class ValidationExceptionFilter implements ExceptionFilter {
  catch(exception: BadRequestException, host: ArgumentsHost) {
    const response = host.switchToHttp().getResponse();
    const message = (exception.getResponse() as any).message;

    response.status(400).json({
      status: false,
      message: Array.isArray(message) ? message[0] : message,
    });
  }
}

import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { useStaticFiles } from './extensions/StaticFileExtensions';
import { useBodyParser } from './extensions/BodyParserExtensions';
import { useClassValidatorContainer } from './extensions/ClassValidatorExtensions';
import { useValidation } from './extensions/ValidationExtensions';
import { useFilters } from './extensions/FilterExtensions';
import { useCors } from './extensions/CorsExtensions';
import { useSwagger } from './extensions/SwaggerExtensions';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  useStaticFiles(app);
  useBodyParser(app);
  useClassValidatorContainer(app);
  useValidation(app);
  useFilters(app);
  useCors(app);
  useSwagger(app);

  const port = process.env.PORT ?? 3000;

  await app.listen(port);
  console.log('🚀 Backend NestJS corriendo en http://localhost:3000');
}
bootstrap();

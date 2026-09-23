import { INestApplication } from "@nestjs/common";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";

export function useSwagger(app: INestApplication) {
    const config = new DocumentBuilder()
        .setTitle('API - Prueba Tecnica')
        .setDescription('Documentación del API con Swagger')
        .setVersion('1.0')
        .addBearerAuth({
            description:
                'Introduza el token de las siguiente manera Bearer {token}',
            name: 'Authorization',
            scheme: 'bearer',
            bearerFormat: 'JWT',
            type: 'http',
            in: 'header',
        })
        .build();

    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('api/docs', app, document);
}
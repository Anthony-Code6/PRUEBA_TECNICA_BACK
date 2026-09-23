import { INestApplication } from "@nestjs/common";

export function useCors(app: INestApplication) {
    app.enableCors({
        origin: true,
        methods: 'GET,POST,PUT,DELETE,PATCH',
        allowedHeaders: 'Content-Type, Authorization',
        credentials: true,
        exposedHeaders: ['Content-Disposition'],
    });
}
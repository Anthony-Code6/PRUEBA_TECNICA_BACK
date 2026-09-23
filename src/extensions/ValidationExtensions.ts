import { INestApplication, ValidationPipe } from "@nestjs/common";

export function useValidation(app: INestApplication) {
    app.useGlobalPipes(new ValidationPipe({
        whitelist: true,
        transform: true,
    }))
}
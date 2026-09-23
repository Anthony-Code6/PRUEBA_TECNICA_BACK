import { INestApplication } from "@nestjs/common";
import { ValidationExceptionFilter } from "src/filter/validation-exception.filter";

export function useFilters(app: INestApplication) {
    app.useGlobalFilters(new ValidationExceptionFilter())
}
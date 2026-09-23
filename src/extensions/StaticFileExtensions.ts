import { INestApplication } from "@nestjs/common";
import { join } from "path";
import * as express from 'express';

export function useStaticFiles(app: INestApplication) {
    app.use(
        '/static',
        express.static(join(__dirname, '..', 'src/users/templates')),
    );
}
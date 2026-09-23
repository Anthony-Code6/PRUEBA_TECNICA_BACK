import { INestApplication } from "@nestjs/common";
import * as bodyParser from "body-parser";

export function useBodyParser(app: INestApplication) {
    app.use(bodyParser.json({ limit: '50mb' }));
    app.use(bodyParser.urlencoded({ limit: '50mb', extended: true }));
}
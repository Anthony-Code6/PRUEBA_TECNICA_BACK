export interface ResponseServer<T> {
    status: boolean
    data?: T
    message: string
}
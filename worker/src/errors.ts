export class HttpError extends Error {
  readonly status: number;
  readonly code: string;
  readonly responseHeaders: Readonly<Record<string, string>>;

  constructor(
    status: number,
    code: string,
    message: string,
    responseHeaders: Readonly<Record<string, string>> = {},
  ) {
    super(message);
    this.name = "HttpError";
    this.status = status;
    this.code = code;
    this.responseHeaders = responseHeaders;
  }
}

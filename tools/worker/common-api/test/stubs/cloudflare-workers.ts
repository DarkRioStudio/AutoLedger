/**
 * Node Vitest runtime stand-in for the Workers-only module.
 * Production type checking and bundling still resolve the real platform module.
 */
export abstract class WorkerEntrypoint<Env = unknown> {
  protected readonly env: Env;

  constructor(_ctx: unknown, env: Env) {
    this.env = env;
  }
}

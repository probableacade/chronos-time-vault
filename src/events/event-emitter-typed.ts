export type EventHandler<T> = (data: T) => Promise<void> | void;

export class TypedEventBus<EventMap extends Record<string, any>> {
  private handlers: Map<keyof EventMap, Set<EventHandler<any>>> = new Map();

  public on<K extends keyof EventMap>(event: K, handler: EventHandler<EventMap[K]>): void {
    if (!this.handlers.has(event)) {
      this.handlers.set(event, new Set());
    }
    this.handlers.get(event)!.add(handler);
  }

  public async emit<K extends keyof EventMap>(event: K, data: EventMap[K]): Promise<void> {
    const set = this.handlers.get(event);
    if (!set) return;
    const promises = Array.from(set).map(h => Promise.resolve(h(data)));
    await Promise.allSettled(promises);
  }
}

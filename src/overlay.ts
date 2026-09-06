import { invoke } from "@tauri-apps/api/core";

const owners = new Set<string>();
let applied = false;
let queue: Promise<void> = Promise.resolve();

function desiredState(): boolean {
  return owners.size > 0;
}

function apply(force: boolean): Promise<void> {
  queue = queue.then(async () => {
    const desired = desiredState();
    if (!force && desired === applied) return;
    await invoke("set_overlay_open", { open: desired });
    applied = desired;
  });
  return queue;
}

export function setRendererOverlay(owner: string, open: boolean): Promise<void> {
  if (!owner || owner.length > 64) {
    return Promise.reject(new Error("Neispravan overlay izvor."));
  }
  if (open) owners.add(owner);
  else owners.delete(owner);
  return apply(false);
}

export function reapplyRendererOverlay(): Promise<void> {
  return apply(true);
}

export function rendererOverlayOpen(): boolean {
  return desiredState();
}

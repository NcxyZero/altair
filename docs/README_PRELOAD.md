# Altair - `src/preload` Folder

This folder is part of the `ReplicatedFirst` service and is used to manage preloaded assets or modules that need to be available **before the game fully loads** on the client.

---

## 📦 Location

ReplicatedFirst


---

## 📄 Purpose

The `src/preload` folder is used to:

- Contain **files that need to be preloaded** (e.g., UI, modules, or assets).
- Prevent accidental deletion of existing instances in `ReplicatedFirst` during development.
- Allow developers to organize preload content cleanly without polluting the root of `ReplicatedFirst`.

---

## 🧠 Behavior in Studio

Unlike the root of `ReplicatedFirst`, files placed inside `src/preload`:

- **Will not be automatically deleted** or replaced by Rojo during synchronization.
- Can be safely modified or used for testing in Studio without affecting production Rojo sync.

---

## ✅ Use Cases

- Preloading UI screens or loading animations.
- Holding modules/scripts needed early in the client lifecycle.
- Caching sound or image assets before full game load.

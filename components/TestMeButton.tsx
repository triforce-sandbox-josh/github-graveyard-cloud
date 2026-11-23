"use client";

import { useCallback, useState } from "react";
import { SpookyToast, type Toast } from "./SpookyToast";

// Small rounded top-bar button that drops the spooky "Tested" popup.
export function TestMeButton() {
  const [toast, setToast] = useState<Toast | null>(null);
  const clearToast = useCallback(() => setToast(null), []);

  return (
    <>
      <button
        type="button"
        onClick={() => setToast({ id: Date.now(), title: "Tested" })}
        className="chip whitespace-nowrap rounded-full px-3 py-1.5 text-sm font-semibold sm:px-3.5"
      >
        Test me
      </button>
      <SpookyToast toast={toast} onDone={clearToast} />
    </>
  );
}

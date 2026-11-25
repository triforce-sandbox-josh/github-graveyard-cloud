import Link from "next/link";
import { AppIcon } from "./Decor";
import { TestMeButton } from "./TestMeButton";

export function TopBar({ home = false }: { home?: boolean }) {
  return (
    <header className="relative z-10 mx-auto flex w-full max-w-6xl items-center justify-between gap-2 px-4 pt-5">
      <Link href="/" className="group inline-flex min-w-0 items-center gap-2.5">
        <AppIcon className="size-9 shrink-0 transition-transform group-hover:-rotate-12" />
        <span className="hidden whitespace-nowrap text-sm font-extrabold tracking-tight min-[400px]:inline sm:text-base">GitHub Graveyard</span>
      </Link>
      <div className="flex shrink-0 items-center gap-2 sm:gap-3">
        <TestMeButton />
        {home ? (
          <span className="script text-2xl text-white sm:text-3xl">happy haunting</span>
        ) : (
          <Link href="/" className="chip whitespace-nowrap rounded-full px-3.5 py-1.5 text-sm font-semibold">
            Dig another
          </Link>
        )}
      </div>
    </header>
  );
}

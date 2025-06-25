import { useState, useEffect } from "react";

// Simple client-side cookie reader
function getCookie(name: string): string | undefined {
  if (typeof document === "undefined") return undefined;
  const match = document.cookie.match(new RegExp("(^| )" + name + "=([^;]+)"));
  return match ? decodeURIComponent(match[2]) : undefined;
}

export function useAbSid() {
  const [sid, setSid] = useState<string | undefined>(undefined);

  useEffect(() => {
    setSid(getCookie("ab_sid"));
  }, []);

  return sid;
}

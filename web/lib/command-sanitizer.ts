/**
 * Command Sanitizer — D001-D012 destructive command blocker
 *
 * Design: false negatives = 0 (no dangerous command passes through)
 *         false positives = minimized (legitimate commands pass)
 */

export interface SanitizeResult {
  allowed: boolean;
  rule?: string;
  message?: string;
}

interface Rule {
  id: string;
  test: (cmd: string) => boolean;
  message: string;
}

// Whitelist: these commands are always allowed without confirmation
const WHITELIST_PATTERNS = [
  /^\/clear$/,
  /^\/model\s+(sonnet|opus|haiku)$/,
];

export function isWhitelistedCommand(command: string): boolean {
  const trimmed = command.trim();
  return WHITELIST_PATTERNS.some((p) => p.test(trimmed));
}

// Normalize command for matching: collapse whitespace, trim
function normalize(cmd: string): string {
  return cmd.replace(/\s+/g, " ").trim();
}

const RULES: Rule[] = [
  // D001: rm -rf /, rm -rf /mnt/*, rm -rf /home/*, rm -rf ~
  {
    id: "D001",
    test: (cmd) => {
      const n = normalize(cmd);
      // Match rm with -rf (or -r -f or -fr etc) targeting /, /mnt, /home, ~
      if (!/\brm\b/.test(n)) return false;
      // Check for recursive+force flags
      const hasRF =
        /\s-[a-zA-Z]*r[a-zA-Z]*f/.test(n) ||
        /\s-[a-zA-Z]*f[a-zA-Z]*r/.test(n) ||
        (/\s-[a-zA-Z]*r\b/.test(n) && /\s-[a-zA-Z]*f\b/.test(n));
      if (!hasRF) return false;
      // Check dangerous targets
      return /\s(\/|\/mnt\/?\*?|\/home\/?\*?|~)\s*([;|&]|$)/.test(n);
    },
    message: "rm -rf on root/mnt/home/~ is absolutely forbidden (D001)",
  },

  // D002: rm -rf on any path outside project working tree
  {
    id: "D002",
    test: (cmd) => {
      const n = normalize(cmd);
      if (!/\brm\b/.test(n)) return false;
      const hasRF =
        /\s-[a-zA-Z]*r[a-zA-Z]*f/.test(n) ||
        /\s-[a-zA-Z]*f[a-zA-Z]*r/.test(n) ||
        (/\s-[a-zA-Z]*r\b/.test(n) && /\s-[a-zA-Z]*f\b/.test(n));
      if (!hasRF) return false;
      // Extract target paths after flags
      const parts = n.split(/\s+/);
      const rmIdx = parts.findIndex((p) => p === "rm");
      if (rmIdx === -1) return false;
      for (let i = rmIdx + 1; i < parts.length; i++) {
        const part = parts[i];
        if (part.startsWith("-")) continue; // skip flags
        if (part === ";" || part === "&&" || part === "||" || part === "|")
          break;
        // Absolute paths outside project tree are suspect
        if (part.startsWith("/") && !part.startsWith("/home/")) {
          return true; // Broad catch for absolute paths to system dirs
        }
        if (
          part.startsWith("/mnt/") ||
          part.startsWith("/etc/") ||
          part.startsWith("/usr/") ||
          part.startsWith("/var/") ||
          part.startsWith("/opt/") ||
          part.startsWith("/bin/") ||
          part.startsWith("/sbin/") ||
          part.startsWith("/lib/") ||
          part.startsWith("/boot/") ||
          part.startsWith("/sys/") ||
          part.startsWith("/proc/") ||
          part.startsWith("/dev/") ||
          part.startsWith("/tmp/") ||
          part.startsWith("/root/")
        ) {
          return true;
        }
      }
      return false;
    },
    message: "rm -rf outside project tree is forbidden (D002)",
  },

  // D003: git push --force, git push -f (without --force-with-lease)
  {
    id: "D003",
    test: (cmd) => {
      const n = normalize(cmd);
      if (!/\bgit\s+push\b/.test(n)) return false;
      if (/--force-with-lease/.test(n)) return false;
      return /\s--force\b/.test(n) || /\s-f\b/.test(n);
    },
    message: "git push --force without --force-with-lease is forbidden (D003)",
  },

  // D004: git reset --hard, git checkout -- ., git restore ., git clean -f
  {
    id: "D004",
    test: (cmd) => {
      const n = normalize(cmd);
      if (/\bgit\s+reset\s+--hard\b/.test(n)) return true;
      if (/\bgit\s+checkout\s+--\s+\./.test(n)) return true;
      if (/\bgit\s+restore\s+\./.test(n)) return true;
      if (/\bgit\s+clean\s+-[a-zA-Z]*f/.test(n)) return true;
      return false;
    },
    message:
      "Destructive git operations (reset --hard, checkout --, restore ., clean -f) are forbidden (D004)",
  },

  // D005: sudo, su, chmod -R, chown -R on system paths
  {
    id: "D005",
    test: (cmd) => {
      const n = normalize(cmd);
      if (/\bsudo\b/.test(n)) return true;
      if (/\bsu\b/.test(n) && /\bsu\s+(-|[a-z])/.test(n)) return true;
      if (/\b(chmod|chown)\s+-[a-zA-Z]*R/.test(n)) {
        // Only block on system paths
        if (
          /\s\/(etc|usr|var|bin|sbin|lib|boot|sys|proc|dev|opt|root|mnt)\b/.test(
            n
          )
        )
          return true;
      }
      return false;
    },
    message:
      "Privilege escalation (sudo/su) or recursive permission changes on system paths are forbidden (D005)",
  },

  // D006: kill, killall, pkill, tmux kill-server, tmux kill-session
  {
    id: "D006",
    test: (cmd) => {
      const n = normalize(cmd);
      if (/\b(killall|pkill)\b/.test(n)) return true;
      if (/\bkill\s+(-\d+\s+)?(\d|%|\$)/.test(n)) return true;
      if (/\bkill\s+-[A-Z]+/.test(n)) return true;
      if (/\btmux\s+kill-(server|session)\b/.test(n)) return true;
      return false;
    },
    message:
      "Process termination (kill/killall/pkill) and tmux kill-server/session are forbidden (D006)",
  },

  // D007: mkfs, dd if=, fdisk, mount, umount
  {
    id: "D007",
    test: (cmd) => {
      const n = normalize(cmd);
      return /\b(mkfs|fdisk|umount)\b/.test(n) ||
        /\bdd\s+if=/.test(n) ||
        /\bmount\s+/.test(n);
    },
    message: "Disk/partition operations (mkfs, dd, fdisk, mount, umount) are forbidden (D007)",
  },

  // D008: curl|bash, wget -O-|sh, curl|sh (pipe-to-shell)
  {
    id: "D008",
    test: (cmd) => {
      const n = normalize(cmd);
      return /\b(curl|wget)\b.*\|\s*(bash|sh|zsh)\b/.test(n);
    },
    message: "Pipe-to-shell (curl|bash, wget|sh) is forbidden (D008)",
  },

  // D009: rails db:reset
  {
    id: "D009",
    test: (cmd) => /\brails\s+db:reset\b/.test(normalize(cmd)),
    message: "rails db:reset is forbidden (D009)",
  },

  // D010: rails db:drop
  {
    id: "D010",
    test: (cmd) => /\brails\s+db:drop\b/.test(normalize(cmd)),
    message: "rails db:drop is forbidden (D010)",
  },

  // D011: rails db:schema:load
  {
    id: "D011",
    test: (cmd) => /\brails\s+db:schema:load\b/.test(normalize(cmd)),
    message: "rails db:schema:load is forbidden (D011)",
  },

  // D012: rails db:migrate:reset
  {
    id: "D012",
    test: (cmd) => /\brails\s+db:migrate:reset\b/.test(normalize(cmd)),
    message: "rails db:migrate:reset is forbidden (D012)",
  },
];

export function sanitizeCommand(command: string): SanitizeResult {
  for (const rule of RULES) {
    if (rule.test(command)) {
      return {
        allowed: false,
        rule: rule.id,
        message: rule.message,
      };
    }
  }
  return { allowed: true };
}

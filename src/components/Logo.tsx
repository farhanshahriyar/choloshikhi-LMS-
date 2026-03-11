import React from "react";
import { GraduationCap } from "lucide-react";

interface LogoProps {
  className?: string;
  iconOnly?: boolean;
}

export const Logo: React.FC<LogoProps> = ({ className = "", iconOnly = false }) => {
  return (
    <div className={`flex items-center gap-2 ${className}`}>
      <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-gradient-to-br from-orange-500 via-rose-500 to-indigo-500 shrink-0 shadow-sm">
        <GraduationCap className="h-5 w-5 text-white" />
      </div>
      {!iconOnly && (
        <span className="font-bold text-xl tracking-tight">
          cholo<span className="opacity-80 font-medium">shikhi</span>
        </span>
      )}
    </div>
  );
};

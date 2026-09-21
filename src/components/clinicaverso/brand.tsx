import logoAsset from "@/assets/clinica-verso-logo.png.asset.json";
import logo6Asset from "@/assets/clinica-verso-logo-6.png.asset.json";
import markAsset from "@/assets/clinica-verso-mark.png.asset.json";

export function Brand({ compact = false, inverse = false }: { compact?: boolean; inverse?: boolean }) {
  return (
    <img
      src={(compact ? markAsset : inverse ? logo6Asset : logoAsset).url}
      alt="ClinicaVerso"
      className={compact ? "h-8 w-8 object-contain" : "h-8 w-auto object-contain"}
    />
  );
}
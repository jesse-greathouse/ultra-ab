'use client';

export default function Conversion({
  onConvert,
  label = "Big Green Button!",
  disabled = false,
}: {
  onConvert: () => void;
  label?: string;
  disabled?: boolean;
}) {
  return (
    <div className="flex flex-col items-center my-8">
      <button
        onClick={onConvert}
        disabled={disabled}
        className={`bg-green-600 hover:bg-green-700 text-white text-xl px-8 py-4 rounded-lg shadow-lg font-bold mb-2 transition-colors ${disabled ? "opacity-50 cursor-not-allowed" : ""}`}
      >
        Convert
      </button>
      <span className="text-lg font-medium text-green-700">{label}</span>
    </div>
  );
}

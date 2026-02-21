import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Enable standalone output for Docker deployment
  output: 'standalone',

  webpack: (config) => {
    // Simple string externals for server-safe packages
    config.externals.push("pino-pretty", "lokijs", "encoding");

    // Packages that contain WASM or Node.js-only code — exclude from browser bundle.
    // The dynamic imports in useDarkPool.ts have keccak256 fallbacks.
    config.externals.push("ffjavascript", "wasmcurves", "circomlibjs", "snarkjs");

    // @react-native-async-storage/async-storage has an invalid identifier name
    // (contains @ and /) — webpack generates `typeof @react-native-...` which is
    // a SyntaxError. Use resolve.alias=false to emit an empty module instead.
    config.resolve.alias = {
      ...config.resolve.alias,
      '@react-native-async-storage/async-storage': false,
    };

    return config;
  },

  // Allow loading circuit files
  async headers() {
    return [
      {
        source: '/circuits/:path*',
        headers: [
          {
            key: 'Content-Type',
            value: 'application/wasm',
          },
        ],
      },
    ];
  },
};

export default nextConfig;

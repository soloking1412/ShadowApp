import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Enable standalone output for Docker deployment
  output: 'standalone',

  webpack: (config) => {
    config.externals.push("pino-pretty", "lokijs", "encoding");
    // Support for snarkjs WASM files
    config.experiments = {
      ...config.experiments,
      asyncWebAssembly: true,
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

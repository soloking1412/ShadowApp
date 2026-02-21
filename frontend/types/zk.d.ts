declare module 'circomlibjs' {
  export function buildPoseidon(): Promise<{
    (inputs: bigint[]): Uint8Array;
    F: {
      toObject(hash: Uint8Array): bigint;
    };
  }>;
  export function buildBabyjub(): Promise<unknown>;
  export function buildMimc7(): Promise<unknown>;
}

declare module 'snarkjs' {
  export const groth16: {
    fullProve(
      input: Record<string, unknown>,
      wasmFile: string,
      zkeyFile: string
    ): Promise<{
      proof: {
        pi_a: string[];
        pi_b: string[][];
        pi_c: string[];
        protocol: string;
        curve: string;
      };
      publicSignals: string[];
    }>;
    verify(
      vkey: Record<string, unknown>,
      publicSignals: string[],
      proof: Record<string, unknown>
    ): Promise<boolean>;
  };
}

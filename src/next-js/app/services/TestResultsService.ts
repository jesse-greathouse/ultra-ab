export interface TestResult {
  id: number;
  sid: string;
  bucket: "A" | "B" | "C";
  url: string;
  did_convert: number; // 0 or 1
  created_at: string;
}

export interface CreateTestResultInput {
  sid: string;
  bucket: "A" | "B" | "C";
  url: string;
  did_convert?: boolean | number;
}

export type TestResultCollection = TestResult[];

export interface TestResultReportLine {
  bucket: "A" | "B" | "C";
  total_sessions: number;
  total_conversions: number;
}

export type TestResultReport = TestResultReportLine[];

export class TestResultsService {
  private static baseUrl = "/api/test_results";

  /**
   * Create a new test result via POST
   */
  static async create(input: CreateTestResultInput): Promise<{ id: number }> {
    const res = await fetch(this.baseUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(input),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(`Failed to create test result: ${res.status} ${JSON.stringify(err)}`);
    }

    return res.json();
  }

  /**
   * Fetch all test results by session ID
   */
  static async fetchBySid(
    sid: string,
    options?: { rows?: number; offset?: number }
  ): Promise<TestResultCollection> {
    const params = new URLSearchParams();
    if (options?.rows) params.set("rows", String(options.rows));
    if (options?.offset) params.set("offset", String(options.offset));

    const url = `${this.baseUrl}/${encodeURIComponent(sid)}${params.size ? "?" + params.toString() : ""}`;

    const res = await fetch(url, { method: "GET" });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(`Failed to fetch test results: ${res.status} ${JSON.stringify(err)}`);
    }

    return res.json();
  }

  /**
   * Fetch a single test result by its numeric ID
   */
  static async fetchById(id: number): Promise<TestResult> {
    const url = `${this.baseUrl}/${id}`;
    const res = await fetch(url, { method: "GET" });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(`Failed to fetch test result by id: ${res.status} ${JSON.stringify(err)}`);
    }

    return res.json();
  }

  /**
   * Update a test result by its numeric ID
   */
  static async updateById(id: number, input: CreateTestResultInput): Promise<TestResult> {
    const res = await fetch(`${this.baseUrl}/${id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(input),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(`Failed to update test result: ${res.status} ${JSON.stringify(err)}`);
    }
    return res.json(); // Should be TestResult shape
  }

  /**
   * Get summary report across all buckets
   */
  static async getReport(): Promise<TestResultReport> {
    const res = await fetch(`${this.baseUrl}/report`, { method: "GET" });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(`Failed to fetch test result report: ${res.status} ${JSON.stringify(err)}`);
    }

    return res.json();
  }
}

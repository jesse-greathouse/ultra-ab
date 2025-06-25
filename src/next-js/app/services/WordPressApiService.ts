export interface WPRenderedText {
  rendered: string;
  protected?: boolean;
}

export interface WPLinkTargetHint {
  allow?: string[];
}

export interface WPLinkItem {
  href: string;
  embeddable?: boolean;
  templated?: boolean;
  targetHints?: WPLinkTargetHint;
  taxonomy?: string;
  name?: string;
}

export interface WPLinks {
  self?: WPLinkItem[];
  collection?: WPLinkItem[];
  about?: WPLinkItem[];
  author?: WPLinkItem[];
  replies?: WPLinkItem[];
  "version-history"?: WPLinkItem[];
  "wp:attachment"?: WPLinkItem[];
  "wp:term"?: WPLinkItem[];
  curies?: WPLinkItem[];
  [key: string]: WPLinkItem[] | undefined;
}

export interface WordPressPost {
  id: number;
  date: string;
  date_gmt: string;
  guid: WPRenderedText;
  modified: string;
  modified_gmt: string;
  slug: string;
  status: string;
  type: string;
  link: string;
  title: WPRenderedText;
  content: WPRenderedText;
  excerpt: WPRenderedText;
  author: number;
  featured_media: number;
  comment_status: string;
  ping_status: string;
  sticky: boolean;
  template: string;
  format: string;
  meta: {
    footnotes: string;
    [key: string]: any;
  };
  categories: number[];
  tags: number[];
  class_list: string[];
  _links: WPLinks;
}

export type WordPressPostCollection = WordPressPost[];

export class WordPressApiService {
  private static baseUrl = "/api/wp";

  static async get<T = any>(resource: string, params?: Record<string, any>): Promise<T> {
    let url = `${WordPressApiService.baseUrl}/${resource.replace(/^\/+/, "")}`;
    if (params) {
      const qs = new URLSearchParams(params).toString();
      url += `?${qs}`;
    }
    const res = await fetch(url, { method: "GET", credentials: "same-origin" });
    if (!res.ok) throw new Error(`Failed to fetch WordPress API: ${res.status}`);
    return res.json();
  }

  static async post<T = any>(resource: string, body: any): Promise<T> {
    const url = `${WordPressApiService.baseUrl}/${resource.replace(/^\/+/, "")}`;
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "same-origin",
      body: JSON.stringify(body),
    });
    if (!res.ok) throw new Error(`Failed to POST to WordPress API: ${res.status}`);
    return res.json();
  }

  // Fetch a single post
  static async getPost(id: number): Promise<WordPressPost> {
    return this.get<WordPressPost>(`posts/${id}`);
  }

  // Fetch a collection of posts (with optional query params)
  static async getPosts(params?: Record<string, any>): Promise<WordPressPostCollection> {
    return this.get<WordPressPostCollection>("posts", params);
  }
}

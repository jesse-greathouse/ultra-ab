import type { WordPressPost } from "../services/WordPressApiService";

export default function Post({ post }: { post: WordPressPost }) {
  return (
    <article className="prose max-w-none mb-12">
      <h1 className="text-3xl font-bold">{post.title.rendered}</h1>
      <div className="text-gray-500 text-sm mb-2">
        {new Date(post.date).toLocaleString()} &middot; by Author #{post.author}
      </div>
      <div
        className="mb-6"
        dangerouslySetInnerHTML={{ __html: post.content.rendered }}
      />
    </article>
  );
}

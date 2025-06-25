import type { WordPressPost } from "../services/WordPressApiService";

export default function PostPreview({ post, onClick }: { post: WordPressPost; onClick?: () => void }) {
  return (
    <div
      className="border p-4 rounded cursor-pointer hover:bg-gray-50 mb-4"
      onClick={onClick}
      tabIndex={0}
      role="button"
    >
      <h2 className="text-xl font-semibold">{post.title.rendered}</h2>
      <div className="text-gray-500 text-xs mb-1">
        {new Date(post.date).toLocaleDateString()}
      </div>
      <div
        className="line-clamp-2 text-sm text-gray-700"
        dangerouslySetInnerHTML={{ __html: post.excerpt.rendered }}
      />
    </div>
  );
}

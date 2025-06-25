import type { WordPressPost } from "../services/WordPressApiService";
import PostPreview from "./PostPreview";

export default function PostList({
  posts,
  onPostClick,
}: {
  posts: WordPressPost[];
  onPostClick?: (post: WordPressPost) => void;
}) {
  return (
    <div>
      {posts.map((post) => (
        <PostPreview
          key={post.id}
          post={post}
          onClick={onPostClick ? () => onPostClick(post) : undefined}
        />
      ))}
    </div>
  );
}

const mongoose = require('mongoose');

const postSchema = new mongoose.Schema({
  author: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  content: { type: String, default: '' },
  images: [{ type: String }],
  videos: [{ type: String }],
  thumbnails: [{ type: String }],
  replyTo: { type: mongoose.Schema.Types.ObjectId, ref: 'Post', default: null },
  retweetOf: { type: mongoose.Schema.Types.ObjectId, ref: 'Post', default: null },
  likes: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  retweets: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  replyCount: { type: Number, default: 0 },
  viewCount: { type: Number, default: 0 },
}, { timestamps: true });

postSchema.index({ content: 'text' });
postSchema.index({ createdAt: -1 });

module.exports = mongoose.model('Post', postSchema);

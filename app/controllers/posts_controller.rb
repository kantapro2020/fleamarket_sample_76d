class PostsController < ApplicationController
  before_action :set_post, except: [:index, :new, :create, :search, :items]
  before_action :set_parents, only: [:new, :create, :edit, :update]
  before_action :authenticate_user!, except: [:index, :show]
  before_action :block_current_user, only: [:buy, :pay]
  before_action :other_user, only: [:edit, :update, :destroy]
  before_action :purchased_item, only: [:buy, :pay]

  def index
    @posts = Post.includes([:post_images, :user]).last(3).reverse
  end

  def new
    @post = Post.new
    @post.post_images.new
  end

  def create
    @post = Post.new(post_params)
    # 投稿内容のsaveと、画像が投稿されてるか確認！（今回の場合は1枚以上）
      if @post.post_images.present? && @post.save 
        redirect_to root_path
      else
        @post.post_images.new
        flash.now[:alert] = "画像がありません"
        render :new
      end
  end

  def edit
  end

  def show
    @images = @post.post_images.includes(:post)
  end

  def update
    # each do で並べた画像が image
    # 新しくinputに追加された画像が image_attributes
    # この二つがない時はupdateしない
    if params[:post].keys.include?("image") || params[:post].keys.include?("post_images_attributes")
      if params[:post].keys.include?("image")
        # dbにある画像がedit画面で一部削除してるか確認
        update_images_ids = params[:post][:image].values #投稿済み画像 
        before_images_ids = @post.post_images.ids
        # 商品に紐づく投稿済み画像が、投稿済みにない場合は削除する
        # before_images_ids.each doで、一つずつimageハッシュにあるか確認。なければdestroy
        before_images_ids.each do |before_img_id|
          PostImage.find(before_img_id).destroy unless update_images_ids.include?("#{before_img_id}")
        end
      else
        # imageハッシュがない = 投稿済みの画像をすべてedit画面で消しているので、商品に紐づく投稿済み画像を削除する。
        before_images_ids = @post.post_images.ids
        # @post.images.destroy = nil と削除されないので、each do で一つずつ削除する
        before_images_ids.each do |before_img_id|
          PostImage.find(before_img_id).destroy 
        end
      end
      @post.update(post_params)
      redirect_to @post, notice: "更新しました"
    else
      flash.now[:alert] = "画像がありません"
      render 'edit'
    end
  end

  def destroy
    if @post.destroy
      redirect_to root_path, notice: "投稿を削除しました"
    else
      flash.now[:alert] = "削除に失敗しました"
      render :edit
    end
  end
  
  def search
    respond_to do |format|
      format.html
      format.json do
        if params[:parent_id]
          @childrens = Category.find(params[:parent_id]).children
        elsif params[:children_id]
          @grandChilds = Category.find(params[:children_id]).children
        end
      end
    end
  end

  def buy
    @address = UserAddress.find_by(user_id: current_user.id)
  end

  def pay
    Payjp.api_key = Rails.application.credentials.payjp[:PAYJP_SECRET_KEY]
    charge = Payjp::Charge.create(
    amount: @post.price,
    card: params['payjp-token'],
    currency: 'jpy'
    )
    @post.update(purchased: true)
    redirect_to root_path, notice: '購入しました！'
  end

  def items
    @posts = Post.includes([:post_images, :user]).order('created_at desc')
  end

  private
  def post_params
    params.require(:post).permit(:name, :introduce, :category_id, :user_address, :shipping, :price, :status, :delivery_status, post_images_attributes: [:image, :_destroy, :id]).merge(user_id: current_user.id)
  end
  
  def set_post
    @post = Post.find(params[:id])
  end

  def set_parents
    @parents = Category.where(ancestry: nil)
  end

  def purchased_item
    if @post.purchased == true
      redirect_to root_path, notice: "その商品は既に購入されています"
    end
  end
  
  def block_current_user
    if @post.user_id == current_user.id
      flash[:alert] = "指定のページへは飛べません"
      redirect_to post_path
    end
  end

  def other_user
    if @post.user_id != current_user.id
      flash[:alert] = "指定されたアクションは動きません"
      redirect_to post_path
    end
  end

end

  # def update
  #   # each do で並べた画像が image
  #   # 新しくinputに追加された画像が image_attributes
  #   # この二つがない時はupdateしない
  #   if params[:product].keys.include?("image") || params[:product].keys.include?("images_attributes") 
  #     if @product.valid?
  #       # dbにある画像がedit画面で一部削除してるか確認
  #       if params[:product].keys.include?("image") 
  #         update_images_ids = params[:product][:image].values #投稿済み画像 
  #         before_images_ids = @product.images.ids
  #         #  商品に紐づく投稿済み画像が、投稿済みにない場合は削除する
  #         # @product.images.ids.each doで、一つずつimageハッシュにあるか確認。なければdestroy
  #         before_images_ids.each do |before_img_id|
  #           Image.find(before_img_id).destroy unless update_image_ids.include?("#{before_img_id}") 
  #         end
  #       else
  #         # imageハッシュがない = 投稿済みの画像をすべてedit画面で消しているので、商品に紐づく投稿済み画像を削除する。
  #         # @product.images.destroy = nil と削除されないので、each do で一つずつ削除する
  #         before_images_ids.each do |before_img_id|
  #           Image.find(before_img_id).destroy 
  #         end
  #       end
  #       @product.update(product_params)
  #       redirect_to item_product_path(@product), notice: "商品を更新しました"
  #     else
  #       render 'edit'
  #     end
  #   else
  #     redirect_back(fallback_location: root_path,flash: {success: '画像がありません'})
  #   end
  # end
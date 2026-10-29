
import '../models/category_model.dart';
import 'base_repository.dart';

class CategoryRepository extends BaseRepository<CategoryModel> {

  CategoryRepository()
      : super(
    collectionName: 'categories',
    fromMap: CategoryModel.fromMap,
    toMap: (item) => item.toMap(),
  );

  // Thêm danh mục
  Future<void> addCategory(CategoryModel category) async {
    await add(
      category.userId,
      category.id,
      category,
    );
  }

  // Lấy tất cả danh mục
  Future<List<CategoryModel>> getCategories(
      String userId,
      ) {
    return getAll(userId);
  }

  // Lấy danh mục theo ID
  Future<CategoryModel?> getCategory(
      String userId,
      String id,
      ) {
    return getById(userId, id);
  }

  // Sửa danh mục
  Future<void> updateCategory(CategoryModel category) async {
    await update(
      category.userId,
      category.id,
      category,
    );
  }

  // Xóa danh mục
  Future<void> deleteCategory(
      String userId,
      String id,
      ) async {
    await delete(userId, id);
  }

  // Lọc danh mục thu hoặc chi
  Future<List<CategoryModel>> getByType(
      String userId,
      String type,
      ) async {
    final categories = await getAll(userId);

    return categories
        .where((item) => item.type == type)
        .toList();
  }

  // Theo dõi danh mục
  Stream<List<CategoryModel>> watchCategories(
      String userId,
      ) {
    return watchAll(userId);
  }
}

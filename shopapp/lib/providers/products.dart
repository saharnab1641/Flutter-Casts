import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shopapp/models/http_exception.dart';
import 'product.dart';
import 'package:http/http.dart' as http;

class Products with ChangeNotifier {
  List<Product> _items = [];
  String authToken;
  String userId;

  set auth(String token) {
    this.authToken = token;
    notifyListeners();
  }

  set user(String id) {
    this.userId = id;
  }

  List<Product> get items {
    return [..._items];
  }

  List<Product> get favouriteItems {
    return _items.where((item) => item.isFavourite).toList();
  }

  Product findById(String id) {
    return _items.firstWhere((prod) => prod.id == id);
  }

  Future<void> fetchAndSetProducts([bool filterByUser = false]) async {
    final filterString =
        filterByUser ? 'orderBy="creatorId"&equalTo"$userId"' : '';
    if (authToken == null) return;
    final url =
        'https://shopapp-864aa.firebaseio.com/products.json?auth=$authToken&$filterString';
    try {
      var response = await http.get(url);
      final extractedData = json.decode(response.body) as Map<String, dynamic>;
      final List<Product> loadedProducts = [];
      if (extractedData == null) return;
      final favouriteUrl =
          'https://shopapp-864aa.firebaseio.com/userFavourites/$userId?auth=$authToken';
      final favouriteResponse = await http.get(favouriteUrl);
      final favouriteData = json.decode(favouriteResponse.body);
      extractedData.forEach((prodId, prodData) {
        loadedProducts.add(Product(
          id: prodId,
          title: prodData['title'],
          description: prodData['description'],
          price: prodData['price'],
          isFavourite:
              favouriteData == null ? false : favouriteData[prodId] ?? false,
          imageUrl: prodData['imageUrl'],
        ));
      });
      _items = loadedProducts;
      notifyListeners();
    } catch (error) {
      throw error;
    }
  }

  Future<void> addProduct(Product product) async {
    if (authToken == null) return;
    final url =
        'https://shopapp-864aa.firebaseio.com/products.json?auth=$authToken';
    try {
      final response = await http.post(
        url,
        body: json.encode(
          {
            'title': product.title,
            'description': product.description,
            'imageUrl': product.imageUrl,
            'price': product.price,
            'id': product.id,
            'creatorId': userId,
          },
        ),
      );

      final newProduct = Product(
        title: product.title,
        imageUrl: product.imageUrl,
        price: product.price,
        description: product.description,
        id: json.decode(response.body)['name'],
      );
      _items.add(newProduct);
      notifyListeners();
    } catch (error) {
      print(error);
      throw error;
    }
  }

  Future<void> updateProduct(String id, Product product) async {
    if (authToken == null) return;
    final prodIndex = _items.indexWhere((prod) => prod.id == id);
    if (prodIndex >= 0) {
      final url =
          'https://shopapp-864aa.firebaseio.com/products/$id.json?auth=$authToken';
      await http.patch(url,
          body: json.encode({
            'title': product.title,
            'description': product.description,
            'imageUrl': product.imageUrl,
            'price': product.price,
            'id': product.id,
          }));
      _items[prodIndex] = product;
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String id) async {
    if (authToken == null) return;
    final url =
        'https://shopapp-864aa.firebaseio.com/products/$id.json?auth=$authToken';
    final existingProductIndex = _items.indexWhere((prod) => prod.id == id);
    var existingProduct = _items[existingProductIndex];
    _items.removeAt(existingProductIndex);
    notifyListeners();
    final response = await http.delete(url);
    if (response.statusCode >= 400) {
      _items.insert(existingProductIndex, existingProduct);
      notifyListeners();
      throw HttpException('Could not delete product.');
    }
    existingProduct = null;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:korean_language_app/shared/presentation/widgets/errors/error_widget.dart';
import 'package:korean_language_app/features/books/presentation/bloc/book_search/book_search_cubit.dart';
import 'package:korean_language_app/features/books/presentation/bloc/favorite_books/favorite_books_cubit.dart';
import 'package:korean_language_app/shared/presentation/language_preference/bloc/language_preference_cubit.dart';
import 'package:korean_language_app/features/books/data/models/book_item.dart';
import 'package:korean_language_app/features/books/presentation/widgets/book_list_card.dart';

class BookSearchDelegate extends SearchDelegate<BookItem?> {
  final BookSearchCubit bookSearchCubit;
  final FavoriteBooksCubit favoriteBooksCubit;
  final LanguagePreferenceCubit languageCubit;
  final Function(BookItem) onToggleFavorite;
  final Function(BookItem) onViewPdf;
  final Function(BookItem)? onEditBook;
  final Function(BookItem)? onDeleteBook;
  final Function(BookItem)? onQuizBook;
  final Future<bool> Function(String) checkEditPermission;
  final Function(BookItem)? onInfoClicked;
  final Function(BookItem)? onDownloadClicked;
  
  BookSearchDelegate({
    required this.bookSearchCubit,
    required this.favoriteBooksCubit,
    required this.languageCubit,
    required this.onToggleFavorite,
    required this.onViewPdf,
    this.onEditBook,
    this.onDeleteBook,
    this.onQuizBook,
    required this.checkEditPermission,
    required this.onInfoClicked,
    required this.onDownloadClicked,
  });
  
  @override
  String get searchFieldLabel => languageCubit.getLocalizedText(
    korean: '책 검색',
    english: 'Search books',
  );
  
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }
  
  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        bookSearchCubit.clearSearch();
        close(context, null);
      },
    );
  }
  
  @override
  Widget buildResults(BuildContext context) {
    if (query.length < 2) {
      return _buildMinQueryLengthMessage(context);
    }
    
    bookSearchCubit.searchBooks(query);
    
    return BlocBuilder<BookSearchCubit, BookSearchState>(
      bloc: bookSearchCubit,
      builder: (context, state) {
        if (state.isLoading && state.searchResults.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (state.hasError && state.searchResults.isEmpty) {
          return ErrorView(
            message: state.error ?? '',
            errorType: state.errorType,
            onRetry: () {
              bookSearchCubit.searchBooks(query);
            },
          );
        }
        
        final books = state.searchResults;
        
        if (books.isEmpty && state.isSearching) {
          return _buildNoResultsMessage(context);
        }
        
        return _buildSearchResults(context, books);
      },
    );
  }
  
  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.length < 2) {
      return _buildSearchPrompt(context);
    }
    
    bookSearchCubit.searchBooks(query);
    
    return buildResults(context);
  }
  
  Widget _buildMinQueryLengthMessage(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            languageCubit.getLocalizedText(
              korean: '검색어는 2자 이상이어야 합니다',
              english: 'Search term must be at least 2 characters',
            ),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            languageCubit.getLocalizedText(
              korean: '책 제목이나 내용으로 검색하세요',
              english: 'Search by book title or content',
            ),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNoResultsMessage(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            languageCubit.getLocalizedText(
              korean: '검색 결과 없음',
              english: 'No results found',
            ),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            languageCubit.getLocalizedText(
              korean: '"$query"에 대한 결과를 찾을 수 없습니다',
              english: 'No results found for "$query"',
            ),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              query = '';
            },
            child: Text(
              languageCubit.getLocalizedText(
                korean: '다시 검색',
                english: 'Search Again',
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchResults(BuildContext context, List<BookItem> books) {
    return ListView.builder(
      itemCount: books.length,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemBuilder: (context, index) {
        final book = books[index];
        
        return BlocBuilder<FavoriteBooksCubit, FavoriteBooksState>(
          builder: (context, favoritesState) {
            bool isFavorite = false;
            
            isFavorite = favoritesState.books.any((favBook) => favBook.id == book.id);
            
            return FutureBuilder<bool>(
              future: checkEditPermission(book.id),
              builder: (context, snapshot) {
                final canEdit = snapshot.data ?? false;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: BookListCard(
                    book: book,
                    isFavorite: isFavorite,
                    canEdit: canEdit,
                    onToggleFavorite: onToggleFavorite,
                    onViewPdf: onViewPdf,
                    onEditBook: onEditBook,
                    onDeleteBook: onDeleteBook,
                    onQuizBook: onQuizBook,
                    onInfoClicked: onInfoClicked,
                    onDownloadClicked: onDownloadClicked,
                  ),
                );
              }
            );
          },
        );
      },
    );
  }
}
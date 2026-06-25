abstract class Failure {
  final String message;
  Failure(this.message);
}

class DatabaseFailure extends Failure {
  DatabaseFailure(String message) : super(message);
}

class GenerationFailure extends Failure {
  GenerationFailure(String message) : super(message);
}

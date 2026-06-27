abstract class Failure {
  final String message;
  Failure(this.message);
}

class DatabaseFailure extends Failure {
  DatabaseFailure(super.message);
}

class GenerationFailure extends Failure {
  GenerationFailure(super.message);
}

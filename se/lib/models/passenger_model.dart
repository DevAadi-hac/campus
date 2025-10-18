
class Passenger {
  String name;
  int age;
  String gender;
  String aadhaarNumber;

  Passenger({
    required this.name,
    required this.age,
    required this.gender,
    required this.aadhaarNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'gender': gender,
      'aadhaarNumber': aadhaarNumber,
    };
  }
}

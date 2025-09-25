
// This class contains all the App Text in String formats.

class AppTexts {

  // -- GLOBAL Texts
  static const String and = "and";
  static const String skip = "Skip";
  static const String done = "Done";
  static const String submit = "Submit";
  static const String appName = "Palventure";
  static const String tContinue = "Continue";

  // -- OnBoarding Texts
  static const String onBoardingTitle1 = "Choose your interests";
  static const String onBoardingTitle2 = "Reach your Goals";
  static const String onBoardingTitle3 = "Geographical Based Opportunities";

  static const String onBoardingSubTitle1= "Welcome to a World of Limitless Opportunities!";
  static const String onBoardingSubTitle2 = "For Seamless Transactions, Choose Your Payment Path - Your Convenience, Our Priority!";
  static const String onBoardingSubTitle3 = "From Our Doorstep to Yours - Swift, Secure, and Contactless Delivery!";

  // -- AppBar

  static String appbarTitle = getGreetingMessage();

  static const String homeAppbarSubTitle = "Mahmoud Fannoun";
  static const String exploreAppbarSubTitle = "Explore with Us";
  static const String alertsAppbarSubTitle = "Alerts And Applications";
  static const String profileAppbarSubTitle = "Profile";

 // Authentication Form Text
  static const String firstName = "First Name";
  static const String lastName = "Last Name";
  static const String email = "E-Mail";
  static const String password = "Password";
  static const String newPassword = "New Password";
  static const String username = "Username";
  static const String phoneNo = "Phone Number";
  static const String rememberMe = "Remember Me";
  static const String forgetPassword = "Forget Password?";
  static const String signIn = "Sign In";
  static const String createAccount = "Create Account";
  static const String orSignInWith = "Or Sign In With";
  static const String orSignUpWith = "Or Sign Up With";
  static const String agreeTo = "I Agree to";
  static const String privacyPolicy = "Privacy Policy";
  static const String termsOfUse = "Terms of Use.";
  static const String verificationCode = "Verification Code";
  static const String resendEmail = "Resend Email";
  static const String resendEmailIn = "Resend email in";
  static const String next = "Next";
  static const String $continue = "Continue";
  static const String orContinueWith = "Or Continue With";


  // Authentication Headings Text
  static const String loginTitle = "Welcome back";
  static const String signUpTitle = "Let's create your account";
  static const String loginSubTitle = "Discover Limitless Opportunities.";
  static const String forgetPasswordTitle = "Forget password";
  static const String forgetPasswordSubTitle = "Don't worry, sometimes people can forget too, enter your email and we will send you a password reset link.";
  static const String changeYourPasswordTitle = "Password Reset Email Sent";
  static const String changeYourPasswordSubTitle = "Your Account Security is Our Priority! We've Sent You a Secure Link to Safely Change Your Password and Keep Your Account Protected.";
  static const String confirmEmailTitle = "Your Account Awaits";
  static const String confirmEmailSubTitle = "Verify Your Email to Start Experiencing a World of Limitless Opportunities.";
  static const String emailNotReceivedMessage = "Didn’t get the email? Check your Junk/Spam or resend it.";
  static const String yourAccountCreatedTitle = "Your account successfully created!";
  static const String yourAccountCreatedSubTitle = "Welcome: Your Account is Created";






}

String getGreetingMessage() {
  final hour = DateTime.now().hour;

  if (hour >= 5 && hour < 12) {
    return 'Good Morning ☀️';
  } else if (hour >= 12 && hour < 17) {
    return 'Good Afternoon 🌤️';
  } else {
    return 'Good Evening 🌙';
  }
}

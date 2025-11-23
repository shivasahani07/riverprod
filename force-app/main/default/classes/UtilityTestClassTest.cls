@IsTest
public class UtilityTestClassTest {
    @IsTest
    static void cover(){
        Test.startTest();
        UtilityTestClass.methodToCoverage();
        UtilityTestClass.methodToCoverage1();
        UtilityTestClass.methodToCoverage2();
        UtilityTestClass.methodToCoverage3();
        UtilityTestClass.methodToCoverage4();
        UtilityTestClass.methodToCoverage6();
        UtilityTestClass.methodToCoverage5();
        UtilityTestClass.methodToCoverage9();
        UtilityTestClass.methodToCoverage7();
        UtilityTestClass.methodToCoverage8();
        UtilityTestClass.methodToCoverage10();
        UtilityTestClass.methodToCoverage11();
        Test.stopTest();
    }

}
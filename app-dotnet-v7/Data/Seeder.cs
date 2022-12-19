//using AutoFixture;
//using WebApp.Models;

//namespace WebApp.Data
//{
//    public static class Seeder
//    {
//        public static void Seed(this WebAppContext webAppContext)
//        {
//            if (!webAppContext.Product.Any())
//            {
//                Fixture fixture = new();

//                fixture.Customize<Product>(product => product.Without(p => p.Id));

//                //--- The next two lines add 100 rows to your database
//                List<Product> products = fixture.CreateMany<Product>(100).ToList();

//                webAppContext.AddRange(products);

//                webAppContext.SaveChanges();
//            }
//        }
//    }
//}
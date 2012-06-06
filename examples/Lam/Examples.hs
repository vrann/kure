module Lam.Examples where

import Language.KURE

import Lam.AST
import Lam.Kure

import Data.List (nub)
import Control.Monad (guard)
import Control.Arrow

------------------------------------------------------------------------

freeVarsT :: TranslateExp [Name]
freeVarsT = fmap nub $ crushbuT $ do (c, Var v) <- exposeT
                                     guard (v `notElem` c)
                                     return [v]

freeVars :: Exp -> [Name]
freeVars = either error id . applyExp freeVarsT

-- Only works for lambdas, fails for all others
alphaLam :: [Name] -> RewriteExp
alphaLam frees = do Lam v e <- idR
                    v' <- constT $ freshName $ frees ++ v : freeVars e
                    lamT (tryR $ substExp v (Var v')) (\ _ -> Lam v')

substExp :: Name -> Exp -> RewriteExp
substExp v s = rules_var <+ rules_lam <+ rule_app
 where
        -- From Lambda Calc Textbook, the 6 rules.
        rules_var = whenM (varT (==v)) (return s)                   -- Rule 1

        rules_lam = do Lam n e <- idR
                       guard (n /= v)                               -- Rule 3
                       guard (v `elem` freeVars e)                  -- Rule 4a
                       if n `elem` freeVars s
                        then alphaLam (freeVars s) >>> rules_lam    -- Rule 5
                        else lamR (substExp v s)                    -- Rule 4b

        rule_app = do App _ _ <- idR
                      anyR (substExp v s)                           -- Rule 6

------------------------------------------------------------------------

beta_reduce :: RewriteExp
beta_reduce = do App (Lam v _) e2 <- idR
                 focusT (pathL [0,0]) (tryR $ substExp v e2)

eta_expand :: RewriteExp
eta_expand = rewrite $ \ c f -> do v <- freshName c
                                   return $ Lam v (App f (Var v))

eta_reduce :: RewriteExp
eta_reduce = contextfreeT $ \ e -> case e of
                               Lam v1 (App f (Var v2)) -> do guardFail (v1 == v2) $ "Cannot eta-reduce, " ++ v1 ++ " /= " ++ v2
                                                             return f
                               _                       -> fail "Cannot eta-reduce, not lambda-app-var."

-- This might not actually be normal order evaluation
-- Contact the  KURE maintainer if you can correct this definition.
normal_order_eval :: RewriteExp
normal_order_eval = anytdR (repeatR beta_reduce)

-- This might not actually be applicative order evaluation
-- Contact the  KURE maintainer if you can correct this definition.
applicative_order_eval :: RewriteExp
applicative_order_eval = innermostR beta_reduce

------------------------------------------------------------------------

type LamTest = (RewriteExp,String,Exp,Maybe Exp)

runLamTest :: LamTest -> (Bool, String)
runLamTest (r,_,e,me) = case (applyExp r e , me) of
                        (Right r1 , Just r2) | r1 == r2 -> (True, show r1)
                        (Left msg , Nothing)            -> (True, msg)
                        (Left msg , Just _)             -> (False, msg)
                        (Right r1 , _     )             -> (False, show r1)

ppLamTest :: LamTest -> IO ()
ppLamTest t@(_,n,e,me) = do putStrLn $ "Rewrite: " ++ n
                            putStrLn $ "Initial expression: " ++ show e
                            putStrLn $ "Expected outcome: " ++ maybe "failure" show me
                            let (b,msg) = runLamTest t
                            putStrLn $ "Actual outcome: " ++ msg
                            putStrLn (if b then "TEST PASSED" else "TEST FAILED")
                            putStrLn ""

------------------------------------------------------------------------

x :: Exp
x = Var "x"

y :: Exp
y = Var "y"

z :: Exp
z = Var "z"

g :: Exp
g = Var "g"

h :: Exp
h = Var "h"

gx :: Exp
gx = App g x

gy :: Exp
gy = App g y

gz :: Exp
gz = App g z

hz :: Exp
hz = App h z

g0 :: Exp
g0 = App g (Var "0")

xx :: Exp
xx = App x x

yy :: Exp
yy = App y y

xz :: Exp
xz = App x z

fix :: Exp
fix = Lam "g" (App body body)
  where
    body = Lam "x" (App g xx)

------------------------------------------------------------------------

test_eta_exp1 :: LamTest
test_eta_exp1 = (eta_expand, "eta-expand", g, Just (Lam "0" g0))

test_eta_exp2 :: LamTest
test_eta_exp2 = (eta_expand, "eta-expand", App (Lam "g" gx) (Lam "y" yy), Just (Lam "0" (App (App (Lam "g" gx) (Lam "y" yy)) (Var "0"))))

test_eta_red1 :: LamTest
test_eta_red1 = (eta_reduce, "eta-reduce", Lam "x" gx , Just g)

test_eta_red2 :: LamTest
test_eta_red2 = (eta_reduce, "eta-reduce", Lam "x" gy, Nothing)

test_eta_red3 :: LamTest
test_eta_red3 = (eta_reduce, "eta-reduce", g, Nothing)

test_beta_red1 :: LamTest
test_beta_red1 = (beta_reduce, "beta-reduce", App (Lam "x" gx) z, Just gz)

test_beta_red2 :: LamTest
test_beta_red2 = (beta_reduce, "beta-reduce", App (Lam "x" gy) z, Just gy)

test_beta_red3 :: LamTest
test_beta_red3 = (beta_reduce, "beta-reduce", App x (Lam "y" gy), Nothing)

test_beta_reds1 :: LamTest
test_beta_reds1 = (anybuR beta_reduce, "any bottom-up beta-reduce", gx, Nothing)

test_beta_reds2 :: LamTest
test_beta_reds2 = (anybuR beta_reduce, "any bottom-up beta-reduce", App (Lam "g" gx) (Lam "h" (App h (App (Lam "y" y) z)))
                                                                  , Just (App (Lam "h" hz) x))

test_beta_reds3a :: LamTest
test_beta_reds3a = (beta_reduce, "beta-reduce", App (Lam "g" gx) (Lam "h" (App h (App (Lam "y" y) z)))
                                              , Just (App (Lam "h" (App h (App (Lam "y" y) z))) x))

test_beta_reds3 :: LamTest
test_beta_reds3 = (normal_order_eval, "normal order evaluation", App (Lam "g" gx) (Lam "h" (App h (App (Lam "y" y) z)))
                                                               , Just xz)

test_beta_reds4 :: LamTest
test_beta_reds4 = (applicative_order_eval, "applicative order evaluation", App (Lam "g" gx) (Lam "h" (App h (App (Lam "y" y) z)))
                                                                         , Just xz)

test_fix1 :: LamTest
test_fix1 = (normal_order_eval, "normal order evaluation", App fix (Lam "_" x), Just x)

diverge :: Either String Exp
diverge = applyExp applicative_order_eval (App fix (Lam "_" x))

test_fix2 :: LamTest
test_fix2 = (anybuR (andR $ replicate 3 $ anybuR beta_reduce), "applicative order evaluation - 3 step cap", App fix (Lam "_" x)
                                                             , Just (App (Lam "g" (App g (App g (App g (App g (App g (App g (App (Lam "x" (App g xx)) (Lam "x" (App g xx))))))))))
                                                                    (Lam "_" x))
                                                             )

all_tests :: [LamTest]
all_tests =    [ test_eta_exp1
               , test_eta_exp2
               , test_eta_red1
               , test_eta_red2
               , test_eta_red3
               , test_beta_red1
               , test_beta_red2
               , test_beta_red3
               , test_beta_reds1
               , test_beta_reds2
               , test_beta_reds3
               , test_beta_reds4
               , test_fix1
               , test_fix2
               ]

checkTests :: Bool
checkTests = all (fst . runLamTest) all_tests

printTests :: IO ()
printTests = mapM_ ppLamTest all_tests

------------------------------------------------------------------------
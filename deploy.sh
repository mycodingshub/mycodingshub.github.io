#!/bin/sh

# 스크립트 실행 중 오류 발생 시 즉시 중단
set -e

# 1. 이전 빌드 결과물 삭제
echo "Deleting old public directory..."
rm -rf public

# 2. 사이트 빌드
echo "Building Hugo site..."
hugo

# 3. GitHub Pages가 Jekyll을 무시하도록 .nojekyll 파일 생성
cd public
touch .nojekyll
cd ..

# 4. 배포
git add -f public/
git checkout -b temp-for-deploy-gh-pages
git commit -m "Build and deploy Hugo site"
git subtree split --prefix public -b gh-pages
git push -f origin gh-pages:gh-pages
git branch -D gh-pages
git checkout main
git branch -D temp-for-deploy-gh-pages

echo "Deployment successful!"